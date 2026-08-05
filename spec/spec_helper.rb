# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb", __FILE__)
require "liquid-rails"
require "rspec/rails"
require "capybara/rspec"
require "liquid-rails/matchers"

Liquid::Rails.environment = Liquid::Rails.build_environment(error_mode: :strict)

Rails.backtrace_cleaner.remove_silencers!

# Load support files
require "fixtures/poro"
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.around do |example|
    if example.metadata[:environment_isolation]
      example.run
    else
      Liquid::Environment.dangerously_override(Liquid::Rails.environment) { example.run }
    end
  end

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include Capybara::RSpecMatchers
  config.include ActionController::TestCase::Behavior
end
