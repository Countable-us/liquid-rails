require "spec_helper"

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
end
