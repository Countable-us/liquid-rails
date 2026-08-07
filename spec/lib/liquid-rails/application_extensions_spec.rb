require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe Liquid::Rails::ApplicationExtensions, :environment_isolation do
  around do |example|
    Dir.mktmpdir("liquid-rails-extensions") do |directory|
      @root = Pathname.new(directory)
      example.run
    end
  ensure
    remove_extension_constants
  end

  it "registers a filter from a relative location resolved against the application root" do
    write_extension("app/liquid/filters/example_filter.rb", <<~'RUBY')
      module Liquid
        module Filters
          module ExampleFilter
            def decorate_example(input)
              "example: #{input}"
            end
          end
        end
      end
    RUBY
    environment = Liquid::Environment.new
    configuration = configuration_with(filters_location: "app/liquid/filters", tags_location: nil)

    result = described_class.new(root: @root, configuration:).register(environment)

    expect(result).to equal(environment)
    expect(Liquid::Template.parse("{{ 'value' | decorate_example }}", environment:).render).to eq("example: value")
  end

  it "registers a tag from an absolute location without resolving it against the application root" do
    extensions = @root.join("shared/extensions")
    write_extension_at(extensions.join("example_tag.rb"), <<~RUBY)
      module Liquid
        module Tags
          class ExampleTag < Liquid::Tag
            def render(_context)
              "example tag"
            end
          end
        end
      end
    RUBY
    environment = Liquid::Environment.new
    configuration = configuration_with(filters_location: nil, tags_location: extensions.to_s)

    described_class.new(root: @root.join("application"), configuration:).register(environment)

    expect(Liquid::Template.parse("{% example_tag %}", environment:).render).to eq("example tag")
  end

  it "ignores nested files and files without a Ruby extension" do
    write_extension("app/liquid/filters/direct_filter.rb", <<~RUBY)
      module Liquid
        module Filters
          module DirectFilter
            def direct_extension(input)
              input.upcase
            end
          end
        end
      end
    RUBY
    write_extension("app/liquid/filters/nested/ignored_filter.rb", "raise 'nested extension was loaded'")
    write_extension("app/liquid/filters/ignored.txt", "raise 'non-Ruby extension was loaded'")
    environment = Liquid::Environment.new
    configuration = configuration_with(filters_location: "app/liquid/filters", tags_location: nil)

    described_class.new(root: @root, configuration:).register(environment)

    expect(Liquid::Template.parse("{{ 'value' | direct_extension }}", environment:).render).to eq("VALUE")
  end

  it "loads direct extension files in lexical order" do
    write_extension("app/liquid/filters/zulu_filter.rb", <<~RUBY)
      Liquid::Filters::ExtensionLoadOrder << :zulu

      module Liquid
        module Filters
          module ZuluFilter
            def zulu_extension(input)
              input
            end
          end
        end
      end
    RUBY
    write_extension("app/liquid/filters/alpha_filter.rb", <<~RUBY)
      Liquid::Filters::ExtensionLoadOrder << :alpha

      module Liquid
        module Filters
          module AlphaFilter
            def alpha_extension(input)
              input
            end
          end
        end
      end
    RUBY
    Liquid.const_set(:Filters, Module.new) unless Liquid.const_defined?(:Filters, false)
    Liquid::Filters.const_set(:ExtensionLoadOrder, [])
    environment = Liquid::Environment.new
    configuration = configuration_with(filters_location: "app/liquid/filters", tags_location: nil)

    described_class.new(root: @root, configuration:).register(environment)

    expect(Liquid::Filters::ExtensionLoadOrder).to eq(%i[alpha zulu])
  end

  it "reloads an extension after Rails unloads its constant" do
    write_extension("app/liquid/filters/reloadable_filter.rb", <<~'RUBY')
      module Liquid
        module Filters
          module ReloadableFilter
            def reloadable_extension(input)
              "reloaded: #{input}"
            end
          end
        end
      end
    RUBY
    configuration = configuration_with(filters_location: "app/liquid/filters", tags_location: nil)
    loader = described_class.new(root: @root, configuration:)

    loader.register(Liquid::Environment.new)
    unloaded_filter = Liquid::Filters.send(:remove_const, :ReloadableFilter)
    environment = Liquid::Environment.new

    loader.register(environment)

    expect(Liquid::Filters::ReloadableFilter).not_to equal(unloaded_filter)
    expect(Liquid::Template.parse("{{ 'value' | reloadable_extension }}", environment:).render).to eq("reloaded: value")
  end

  it "treats missing locations as empty" do
    environment = Liquid::Environment.new
    configuration = configuration_with(filters_location: "missing/filters", tags_location: "missing/tags")

    result = described_class.new(root: @root, configuration:).register(environment)

    expect(result).to equal(environment)
  end

  it "treats nil locations as empty" do
    environment = Liquid::Environment.new
    configuration = configuration_with(filters_location: nil, tags_location: nil)

    result = described_class.new(root: @root, configuration:).register(environment)

    expect(result).to equal(environment)
  end

  private

  def configuration_with(filters_location:, tags_location:)
    Struct.new(:filters_location, :tags_location).new(filters_location, tags_location)
  end

  def write_extension(relative_path, contents)
    write_extension_at(@root.join(relative_path), contents)
  end

  def write_extension_at(path, contents)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
  end

  def remove_extension_constants
    if Liquid.const_defined?(:Filters, false)
      %i[AlphaFilter DirectFilter ExampleFilter ExtensionLoadOrder ReloadableFilter ZuluFilter].each do |name|
        Liquid::Filters.send(:remove_const, name) if Liquid::Filters.const_defined?(name, false)
      end
    end

    Liquid::Tags.send(:remove_const, :ExampleTag) if Liquid::Tags.const_defined?(:ExampleTag, false)
  end
end
