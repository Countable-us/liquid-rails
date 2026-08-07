require "rubygems"
require_relative "../../../lib/liquid-rails/version"

RSpec.describe "liquid-rails.gemspec" do
  subject(:gemspec) do
    Gem::Specification.load(File.expand_path("../../../liquid-rails.gemspec", __dir__))
  end

  it "declares the 1.0 support contract" do
    expect(gemspec.version.to_s).to eq("1.0.0")
    expect(gemspec.required_ruby_version).to be_satisfied_by(Gem::Version.new("3.3.0"))
    expect(gemspec.required_ruby_version).not_to be_satisfied_by(Gem::Version.new("3.2.9"))

    dependencies = gemspec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement.to_s] }
    expect(dependencies).to include("rails" => ">= 8.0, < 8.2", "liquid" => ">= 5.13, < 6")
    expect(dependencies).not_to have_key("kaminari")
  end
end
