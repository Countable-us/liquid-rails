require "spec_helper"
require "open3"

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

  it "reinstalls replacement Zeitwerk extension classes after a development reload" do
    script = <<~RUBY
      loader = Rails.autoloaders.main
      extension_names = %w[
        Liquid::Filters::DevelopmentFilter
        Liquid::Tags::DevelopmentTag
      ]

      abort "development reloading is disabled" unless Rails.application.config.enable_reloading
      abort "Liquid extensions are not managed by Zeitwerk" unless extension_names.all? { |name| loader.unloadable_cpath?(name) }

      old_filter = Liquid::Filters::DevelopmentFilter
      old_tag = Liquid::Tags::DevelopmentTag
      old_generation = Liquid::Rails.environment_generation

      Rails.application.reloader.reload!

      abort "filter class object was not replaced" if old_filter.equal?(Liquid::Filters::DevelopmentFilter)
      abort "tag class object was not replaced" if old_tag.equal?(Liquid::Tags::DevelopmentTag)
      abort "environment generation did not advance" unless Liquid::Rails.environment_generation > old_generation
      abort "replacement filter was not installed" unless Liquid::Rails.environment.strainer_template.ancestors.include?(Liquid::Filters::DevelopmentFilter)
      abort "replacement tag was not installed" unless Liquid::Rails.environment.tags.fetch("development_tag").equal?(Liquid::Tags::DevelopmentTag)

      puts "development extensions reloaded"
    RUBY

    output, status = Open3.capture2e(
      {"RAILS_ENV" => "development"},
      Rails.root.join("bin/rails").to_s,
      "runner",
      script,
      chdir: Rails.root
    )

    expect(status).to be_success, output
    expect(output).to include("development extensions reloaded")
  end
end
