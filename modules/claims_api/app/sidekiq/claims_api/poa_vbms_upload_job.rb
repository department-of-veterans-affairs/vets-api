# frozen_string_literal: true

require 'claims_api/vbms_uploader'
require 'claims_api/poa_vbms_sidekiq'
require 'bd/bd'

module ClaimsApi
  class PoaVBMSUploadJob < ClaimsApi::ServiceBase
    include ClaimsApi::PoaVbmsSidekiq

    # Uploads a 21-22 or 21-22a form for a given POA request to VBMS.
    # If successfully uploaded, it queues a job to update the POA code in BGS, as well.
    #
    # @param power_of_attorney_id [String] Unique identifier of the submitted POA
    def perform(power_of_attorney_id, action: 'post')
      power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      uploader = ClaimsApi::PowerOfAttorneyUploader.new(power_of_attorney_id)
      uploader.retrieve_from_store!(power_of_attorney.file_data['filename'])
      file_path = fetch_file_path(uploader)

      if Flipper.enabled?(:lighthouse_claims_api_poa_use_bd)
        benefits_doc_api.upload(claim: power_of_attorney, pdf_path: file_path, action:, doc_type: 'L075')
      else
        upload_to_vbms(power_of_attorney, file_path)
      end

      ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id)
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
      raise
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

    private

    def benefits_doc_api
      ClaimsApi::BD.new
    end
  end
end
