module Liquid
  module Rails
    module AssetUrlFilter
      delegate \
                :asset_path,

                :audio_path,
                :audio_url,

                :font_path,
                :font_url,

                :image_path,
                :image_url,

                :javascript_path,
                :javascript_url,

                :stylesheet_path,
                :stylesheet_url,

                :video_path,
                :video_url,

                to: :__h__

      def asset_url(filename)
        @context.registers[:view].rails_blob_url(
          Current.site.assets.blobs.find_by(filename: filename)
        )
      end

      private

        def __h__
          @context.registers[:view]
        end
    end
  end
end

Liquid::Template.register_filter(Liquid::Rails::AssetUrlFilter)
