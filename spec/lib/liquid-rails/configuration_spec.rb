require "spec_helper"
require "pathname"

RSpec.describe Liquid::Rails::Configuration do
  describe "application extension locations" do
    it "defaults to the conventional relative filter and tag paths" do
      configuration = described_class.new

      expect(configuration.filters_location).to eq("app/liquid/filters")
      expect(configuration.tags_location).to eq("app/liquid/tags")
    end

    it "accepts strings and Pathname objects as location overrides" do
      configuration = described_class.new
      filters_path = Pathname.new("custom/liquid/filters")

      configuration.filters_location = filters_path
      configuration.tags_location = "custom/liquid/tags"

      expect(configuration.filters_location).to equal(filters_path)
      expect(configuration.tags_location).to eq("custom/liquid/tags")
    end

    it "preserves nil locations to disable discovery" do
      configuration = described_class.new

      configuration.filters_location = nil
      configuration.tags_location = nil

      expect(configuration.filters_location).to be_nil
      expect(configuration.tags_location).to be_nil
    end
  end
end
