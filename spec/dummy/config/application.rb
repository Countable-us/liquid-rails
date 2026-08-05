require_relative "boot"

# Pick the frameworks you want:
require "rails/all"
# require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)
require "liquid-rails"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  end
end
