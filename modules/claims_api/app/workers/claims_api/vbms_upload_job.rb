# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/vbms_uploader'
require 'claims_api/vbms_sidekiq'

module ClaimsApi
  class VBMSUploadJob
    include Sidekiq::Worker
    include ClaimsApi::VBMSSidekiq

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
    rescue VBMS::FilenumberDoesNotExist
      rescue_vbms_file_number_not_found(power_of_attorney)
      raise
    end

    def fetch_file_path(uploader)
      return uploader.file.file unless Settings.evss.s3.uploads_enabled

      stream = URI.parse(uploader.file.url).open
      # stream could be a Tempfile or a StringIO https://stackoverflow.com/a/23666898
      stream.try(:path) || stream_to_temp_file(stream).path
    end

    def stream_to_temp_file(stream, close_stream: true)
      file = Tempfile.new
      file.binmode
      file.write stream.read
      file
    ensure
      file.flush
      file.close
      stream.close if close_stream
    end
  end
end
