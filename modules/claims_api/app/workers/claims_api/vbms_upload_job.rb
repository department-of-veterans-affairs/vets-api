# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/vbms_uploader'
require 'claims_api/vbms_sidekiq'

module ClaimsApi
  class VbmsUploadJob
    include Sidekiq::Worker
    include ClaimsApi::VbmsSidekiq

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      uploader = ClaimsApi::PowerOfAttorneyUploader.new(power_of_attorney_id)
      uploader.retrieve_from_store!(power_of_attorney.file_data['filename'])
      file_path = fetch_file_path(uploader)
      upload_to_vbms(power_of_attorney, file_path)
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
    end

    def fetch_file_path(uploader)
      if Settings.evss.s3.uploads_enabled
        temp = URI.parse(uploader.file.url).open
        temp.path
      else
        uploader.file.file
      end
    end
  end
end
