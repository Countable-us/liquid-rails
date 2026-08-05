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
    builder_entries = Queue.new
    builder_releases = Queue.new
    builder_calls = 0
    builder_calls_lock = Mutex.new
    original_environment = described_class.method(:environment)
    original_builder = described_class.method(:build_environment)

    described_class.define_singleton_method(:environment) do
      worker_entries << true
      worker_releases.pop
      original_environment.call
    end
    described_class.define_singleton_method(:build_environment) do |error_mode:|
      builder_calls_lock.synchronize { builder_calls += 1 }
      builder_entries << true
      builder_releases.pop
      original_builder.call(error_mode:)
    end

    begin
      Timeout.timeout(5) do
        first = Thread.new { described_class.environment }
        second = Thread.new { described_class.environment }

        2.times { worker_entries.pop }
        worker_releases << true
        builder_entries.pop
        worker_releases << true
        2.times { builder_releases << true }
        first_environment = first.value
        second_environment = second.value

        expect(builder_calls).to eq(1)
        expect(first_environment).to equal(second_environment)
        expect(described_class.environment_state.environment).to equal(first_environment)
      end
    ensure
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
