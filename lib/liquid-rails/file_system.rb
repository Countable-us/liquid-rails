require "liquid/file_system"

module Liquid
  module Rails
    class FileSystem
      def initialize(view)
        @view = view
      end

      def read_template_file(template_path)
        controller_path = view.controller_path
        template_path = "#{controller_path}/#{template_path}" unless template_path.include?("/")

        name = template_path.split("/").last
        prefix = template_path.split("/")[0...-1].join("/")
        templates = view.lookup_context.find_all(
          name,
          [prefix],
          true,
          [],
          locale: [view.locale],
          formats: view.formats,
          variants: [],
          handlers: [:liquid]
        )
        raise FileSystemError, "No such template '#{template_path}'" if templates.empty?

        templates.first.source
      end

      private

      attr_reader :view
    end
  end
end
