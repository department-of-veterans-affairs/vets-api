# frozen_string_literal: true

module AppealsApi
  module SupportingEvidence
    class TemporaryStorageUploader < CarrierWave::Uploader::Base
      include SetAWSConfig

      def size_range
        1.byte...25.megabytes
      end

      def initialize(appeal_guid, type)
        super
        @appeal_guid = appeal_guid
        @type = type

        set_storage_options!
      end

      def store_dir
        raise 'missing guid' if @appeal_guid.blank?

        "#{location}/#{@appeal_guid}"
      end

      def location
        @type.to_s
      end

      def set_storage_options!
        if Settings.modules_appeals_api.s3.uploads_enabled
          set_aws_config(
            Settings.modules_appeals_api.s3.aws_access_key_id,
            Settings.modules_appeals_api.s3.aws_secret_access_key,
            Settings.modules_appeals_api.s3.region,
            Settings.modules_appeals_api.s3.bucket
          )
        else
          self.class.storage = :file
        end
      end
    end
  end
end
