# frozen_string_literal: true

require 'claims_api/vbms_uploader'

module VBMS
  class SubmitDependentsPDFJob
    include Sidekiq::Worker
    # Generates PDF for 686c form and uploads to VBMS

    def perform(saved_claim_id, veteran_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      output_path = to_pdf(claim, veteran_info)
      upload_to_vbms(output_path, veteran_info)
    end

    private

    def to_pdf(claim, veteran_info)
      claim.parsed_form.merge!(veteran_info)
      PdfFill::Filler.fill_form(claim)
    end

    def upload_to_vbms(path, veteran_info)
      uploader = ClaimsApi::VbmsUploader.new(
        filepath: path,
        file_number: veteran_info['veteran_information']['ssn'],
        doc_type: '148'
      )

      upload_response = uploader.upload!
    rescue VBMS::Unknown
      rescue_vbms_error()
    rescue Errno::ENOENT
      rescue_file_not_found()
    end

    def fetch_file_path(uploader)
      if Settings.evss.s3.uploads_enabled
        temp = URI.parse(uploader.file.url).open
        temp.path
      else
        uploader.file.file
      end
    end

    def rescue_file_not_found()
      # exception
      # need to add logging
    end

    def rescue_vbms_error()
      # exception
      # need to add logging
    end
  end
end

