require "spec_helper"
require "timeout"

module EnvironmentSpecTestFilter
  def decorated(input)
    "[#{input}]"
  end
end

RSpec.describe Liquid::Rails, :environment_isolation do
  let(:helper) { ActionController::Base.helpers }

  after do
    described_class.environment = described_class.build_environment(error_mode: :strict)
  end

  it "builds an isolated environment with gem defaults" do
    environment = described_class.build_environment(error_mode: :strict) do |configured_environment|
      configured_environment.register_filter(EnvironmentSpecTestFilter)
    end

    expect(environment).not_to equal(Liquid::Environment.default)
    expect(Liquid::Template.parse("{{ 'value' | decorated }}", environment: environment).render).to eq("[value]")
    expect(Liquid::Template.parse("{{ 'value' | decorated }}", environment: Liquid::Environment.default).render).to eq("value")
    template = Liquid::Template.parse("{{ 1234 | number_with_delimiter }}", environment: environment)

    expect(template.render({}, registers: {view: helper})).to eq("1,234")
    default_template = Liquid::Template.parse("{{ 1234 | number_with_delimiter }}", environment: Liquid::Environment.default)

    expect(default_template.render({}, registers: {view: helper})).to eq("1234")
  end

  it "exposes only generic default filters and tags" do
    expect(described_class::DEFAULT_FILTERS).to contain_exactly(
      Liquid::Rails::AssetTagFilter,
      Liquid::Rails::AssetUrlFilter,
      Liquid::Rails::DateFilter,
      Liquid::Rails::NumberFilter,
      Liquid::Rails::SanitizeFilter,
      Liquid::Rails::TextFilter,
      Liquid::Rails::TranslateFilter,
      Liquid::Rails::UrlFilter
    )
    expect(described_class::DEFAULT_TAGS).to eq(
      "content_for" => Liquid::Rails::ContentForTag,
      "yield" => Liquid::Rails::YieldTag,
      "csrf_meta_tags" => Liquid::Rails::CsrfMetaTags,
      "javascript_tag" => Liquid::Rails::JavascriptTag
    )
  end

  it "increments the generation when installing an environment" do
    generation = described_class.environment_generation

    described_class.environment = described_class.build_environment(error_mode: :strict)

    expect(described_class.environment_generation).to eq(generation + 1)
  end

  it "initializes one lazy environment when callers race" do
    described_class.remove_instance_variable(:@environment_state) if described_class.instance_variable_defined?(:@environment_state)
    described_class.remove_instance_variable(:@environment) if described_class.instance_variable_defined?(:@environment)
    described_class.remove_instance_variable(:@environment_generation) if described_class.instance_variable_defined?(:@environment_generation)
    worker_entries = Queue.new
    worker_releases = Queue.new
    worker_progress = Queue.new
    builder_entries = Queue.new
    builder_releases = Queue.new
    contested_points = Queue.new
    builder_calls = 0
    builder_calls_lock = Mutex.new
    original_environment = described_class.method(:environment)
    original_builder = described_class.method(:build_environment)
    environment_mutex = described_class.const_get(:ENVIRONMENT_MUTEX) if described_class.const_defined?(:ENVIRONMENT_MUTEX)
    original_synchronize = environment_mutex&.method(:synchronize)

    described_class.define_singleton_method(:environment) do
      worker = Thread.current[:environment_worker]
      worker_entries << worker
      worker_releases.pop
      worker_progress << worker
      original_environment.call
    end
    described_class.define_singleton_method(:build_environment) do |error_mode:|
      builder_calls_lock.synchronize { builder_calls += 1 }
      worker = Thread.current[:environment_worker]
      builder_entries << worker
      contested_points << worker unless environment_mutex
      builder_releases.pop
      original_builder.call(error_mode:)
    end
    environment_mutex&.define_singleton_method(:synchronize) do |&block|
      contested_points << Thread.current[:environment_worker]
      original_synchronize.call(&block)
    end

    first = nil
    second = nil
    begin
      Timeout.timeout(5) do
        first = Thread.new do
          Thread.current[:environment_worker] = :first
          described_class.environment
        end
        second = Thread.new do
          Thread.current[:environment_worker] = :second
          described_class.environment
        end

        expect([worker_entries.pop, worker_entries.pop]).to contain_exactly(:first, :second)
        worker_releases << true
        expect(worker_progress.pop).to eq(:first)
        expect(builder_entries.pop).to eq(:first)
        expect(contested_points.pop).to eq(:first)
        worker_releases << true
        expect(worker_progress.pop).to eq(:second)
        expect(contested_points.pop).to eq(:second)

        expect(builder_calls).to eq(1)
        builder_releases << true
        first_environment = first.value
        second_environment = second.value

        expect(first_environment).to equal(second_environment)
        expect(original_environment.call).to equal(first_environment)
      end
    ensure
      2.times { builder_releases << true }
      [first, second].compact.each(&:join)
      environment_mutex&.define_singleton_method(:synchronize, original_synchronize)
      described_class.define_singleton_method(:environment, original_environment)
      described_class.define_singleton_method(:build_environment, original_builder)
    end
  end

  it "reads only complete environment and generation state during replacement" do
    initial_state = described_class.environment_state
    replacement = described_class.build_environment(error_mode: :strict)
    starts = Queue.new
    snapshots = Queue.new

    writer = Thread.new do
      starts.pop
      described_class.environment = replacement
    end
    reader = Thread.new do
      starts.pop
      snapshots << described_class.environment_state
    end

    2.times { starts << true }
    writer.value
    reader.value
    state = snapshots.pop

    expect(state).to be_frozen

    if state.environment.equal?(initial_state.environment)
      expect(state.generation).to eq(initial_state.generation)
    else
      expect(state.environment).to equal(replacement)
      expect(state.generation).to eq(initial_state.generation + 1)
    end
  end
end
