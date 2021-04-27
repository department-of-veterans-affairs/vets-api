# frozen_string_literal: true

module Form1010cg
  class PoaUploader < CarrierWave::Uploader::Base
    include SetAWSConfig

    storage :aws

    attr_reader :store_dir

    def initialize(form_attachment_guid) # rubocop:disable Metrics/AbcSize
      super

      set_aws_config(
        Settings.form_10_10cg.poa.s3.aws_access_key_id,
        Settings.form_10_10cg.poa.s3.aws_secret_access_key,
        Settings.form_10_10cg.poa.s3.region,
        Settings.form_10_10cg.poa.s3.bucket
      )

      @store_dir = form_attachment_guid
    end

    def extension_allowlist
      %w[jpg jpeg png pdf]
    end

    def content_type_allowlist
      %w[image/jpg image/jpeg image/png application/pdf]
    end
  end
end
