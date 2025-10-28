module Liquid
  module Rails
    module SanitizeFilter
      delegate \
                :strip_tags,
                :strip_links,

                to: :__h__

      private

        def __h__
          @context.registers[:view]
        end
    end
  end
end

Liquid::Rails.register_filter(Liquid::Rails::SanitizeFilter)
