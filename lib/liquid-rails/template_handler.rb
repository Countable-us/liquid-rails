module Liquid
  module Rails
    class TemplateHandler
      def self.call(template, source = nil)
        source ||= template.source
        metadata = {
          identifier: template.identifier,
          virtual_path: template.virtual_path,
          format: template.format
        }
        "Liquid::Rails::TemplateHandler.new(self).render(#{source.inspect}, local_assigns, #{metadata.inspect})"
      end

      def initialize(view)
        @view = view
        @controller = @view.controller
        @helper = ActionController::Base.helpers
      end

      def render(source, local_assigns = {}, metadata = {})
        state = Liquid::Rails.environment_state
        liquid = parsed_template(source, metadata, state).dup
        liquid.instance_variable_set(:@resource_limits, Liquid::ResourceLimits.new(state.environment.default_resource_limits))

        rendered = if Liquid::Rails.configuration.render_errors == :raise
          liquid.render!(assigns(local_assigns), filters: filters, registers: registers)
        else
          liquid.render(assigns(local_assigns), filters: filters, registers: registers)
        end
        rendered.html_safe
      end

      def filters
        if @controller.respond_to?(:liquid_filters, true)
          @controller.send(:liquid_filters)
        else
          [@controller._helpers]
        end
      end

      def registers
        application_registers = if @view.respond_to?(:liquid_registers)
          (@view.liquid_registers || {}).to_h.dup
        else
          {}
        end

        application_registers.merge(
          view: @view,
          controller: @controller,
          helpers: @helper,
          file_system: Liquid::Rails::FileSystem.new(@view)
        )
      end

      def compilable?
        false
      end

      private

      def assigns(local_assigns)
        controller_assigns = if @controller.respond_to?(:liquid_assigns, true)
          @controller.send(:liquid_assigns)
        else
          @view.assigns
        end
        assigns = controller_assigns.to_h.stringify_keys
        assigns["content_for_layout"] = @view.content_for(:layout) if @view.content_for?(:layout)
        assigns.merge!(local_assigns.to_h.stringify_keys)
      end

      def parsed_template(source, metadata, state)
        namespace = Liquid::Rails.configuration.cache_namespace&.call(@view)
        return parse(source, state) if namespace.nil?

        Liquid::Rails.template_cache.fetch(cache_key(namespace, source, metadata, state)) do
          parse(source, state)
        end
      end

      def cache_key(namespace, source, metadata, state)
        [
          namespace,
          state.generation,
          metadata[:identifier],
          metadata[:virtual_path],
          metadata[:format],
          metadata[:locale] || @view.lookup_context.locale,
          Digest::SHA256.hexdigest(source)
        ]
      end

      def parse(source, state)
        Liquid::Template.parse(source, environment: state.environment)
      end
    end
  end
end
