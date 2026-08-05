require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "the Liquid Rails entry point" do
  it "loads and builds an environment in a fresh Bundler process" do
    root = File.expand_path("../../..", __dir__)
    script = <<~RUBY
      require "liquid-rails"
      Liquid::Rails.environment
    RUBY

    _output, status = Open3.capture2e(
      {"BUNDLE_GEMFILE" => File.join(root, "Gemfile")},
      "bundle", "exec", RbConfig.ruby, "-I#{File.join(root, "lib")}", "-e", script,
      chdir: root
    )

    expect(status).to be_success
  end
end
