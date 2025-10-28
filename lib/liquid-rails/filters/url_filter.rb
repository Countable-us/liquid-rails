module Liquid
  module Rails
    module UrlFilter
      def active_link_to(name, url, options={})
        # active_link_to gem only checks for symbolized keys and this is easier
        # than forking the gem, although we could move it into /lib
        options = options.deep_symbolize_keys

        # active_link_to gem expects the following values of :active to be symbols
        case options[:active]
        when "exclusive", "inclusive", "exact"
          options[:active] = options[:active].to_sym
        end

        @context.registers[:view].active_link_to(name, url.to_s, options)
      end

      def link_to(name, url, options={})
        @context.registers[:view].link_to(name, url.to_s, options)
      end

      def link_to_unless_current(name, url, options={})
        @context.registers[:view].link_to_unless_current(name, url.to_s, options)
      end

      def mail_to(email_address, name=nil, options={})
        @context.registers[:view].mail_to(email_address, name, options)
      end

      def current_page?(path)
        @context.registers[:view].current_page?(path.to_s)
      end

      # Usage:
      # {{'' | url_for: locale: language.iso_code, only_path: true}}
      #
      # TODO: since this is a filter we need to pass in a string as the first argument. Let's remove this requirement.
      def url_for(fix_this, options=nil)
        @context.registers[:view].url_for(options)
      end
    end
  end
end

Liquid::Rails.register_filter(Liquid::Rails::UrlFilter)
