lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "liquid-rails/version"

Gem::Specification.new do |spec|
  spec.name = "liquid-rails"
  spec.version = Liquid::Rails::VERSION
  spec.authors = ["Chamnap Chhorn"]
  spec.email = ["chamnapchhorn@gmail.com"]
  spec.summary = "Renders liquid templates with layout and partial support"
  spec.description = "It allows you to render .liquid templates with layout and partial support. It also provides filters, tags, drops class to be used inside your liquid template."
  spec.homepage = ""
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.required_rubygems_version = ">= 3.5"

  spec.files = `git ls-files -z`.split("\x0")
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 8.0", "< 8.2"
  spec.add_dependency "liquid", ">= 5.13", "< 6"
end
