# frozen_string_literal: true

module Form1010cg
  class PoaUploader < CarrierWave::Uploader::Base
    include SetAWSConfig

    attr_reader :store_dir

    # rubocop:disable Metrics/AbcSize
    def initialize(form_attachment_guid)
      super

      set_aws_config(
        Settings.form_10_10cg.poa.s3.aws_access_key_id,
        Settings.form_10_10cg.poa.s3.aws_secret_access_key,
        Settings.form_10_10cg.poa.s3.region,
        Settings.form_10_10cg.poa.s3.bucket
      )

      @store_dir = form_attachment_guid
    end
    # rubocop:enable Metrics/AbcSize
  end
end
