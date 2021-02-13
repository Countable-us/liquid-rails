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
        if Current.site.assets.present? &&
           Current.site.assets.blobs.where(filename: filename).order(created_at: :desc).first
          @context.registers[:view].rails_blob_url(
            Current.site.assets.blobs.where(filename: filename).order(created_at: :desc).first
          )
        else
          __h__.asset_pack_url(filename)
        end
      end

      private

        def __h__
          @context.registers[:view]
        end
    end
  end
end

Liquid::Template.register_filter(Liquid::Rails::AssetUrlFilter)
