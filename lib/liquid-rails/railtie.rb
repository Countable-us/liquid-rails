module Liquid
  module Rails
    class Railtie < ::Rails::Railtie
      config.app_generators.template_engine :liquid

      initializer "liquid-rails.register_template_handler" do |app|
        ActiveSupport.on_load(:action_view) do
          ActionView::Template.register_template_handler(:liquid, Liquid::Rails::TemplateHandler)
        end
      end

      initializer "liquid-rails.install_application_environment" do |app|
        app.reloader.to_prepare do
          Liquid::Rails.install_application_environment!(root: app.root)
        end
      end
    end
  end
end
