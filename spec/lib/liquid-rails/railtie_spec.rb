require "spec_helper"

describe Liquid::Rails::Railtie do
  context "template_engine :liquid" do
    it "sets template_engine to :liquid" do
      expect(Rails.configuration.app_generators.rails[:template_engine]).to eq(:liquid)
    end
  end

  it "does not inject Droppable into Active Record" do
    expect(ActiveRecord::Base.ancestors).not_to include(Liquid::Rails::Droppable)
  end

  it "rebuilds the application Liquid environment when Rails prepares" do
    generation = Liquid::Rails.environment_generation

    expect(Liquid::Rails).to receive(:install_application_environment!).with(root: Rails.application.root).and_call_original
    expect { Rails.application.reloader.prepare! }.to change(Liquid::Rails, :environment_generation).from(generation).to(generation + 1)
  end
end
