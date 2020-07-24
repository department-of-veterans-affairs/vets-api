# frozen_string_literal: true

require 'claims_api/vbms_uploader'

module VBMS
  class SubmitDependentsPDFJob
    include Sidekiq::Worker
    include SentryLogging

    # Generates PDF for 686c form and uploads to VBMS
    def perform(saved_claim_id, veteran_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      claim.format_and_upload_pdf(veteran_info)
      # output_path = to_pdf(saved_claim_id, veteran_info)
      # upload_to_vbms(output_path, veteran_info, saved_claim_id)
    rescue => e
      send_error_to_sentry(e, claim&.id)
    end

    private

    # def to_pdf(saved_claim_id, veteran_info)
    # claim = SavedClaim::DependencyClaim.find(saved_claim_id)
    #
    # claim.parsed_form.merge!(veteran_info)
    # PdfFill::Filler.fill_form(claim)
    # end

    # def upload_to_vbms(path, veteran_info)
    #   uploader = ClaimsApi::VbmsUploader.new(
    #     filepath: path,
    #     file_number: veteran_info['veteran_information']['ssn'],
    #     doc_type: '148'
    #   )
    #
    #   uploader.upload!
    # end

    # def fetch_file_path(uploader)
    #   if Settings.evss.s3.uploads_enabled
    #     temp = URI.parse(uploader.file.url).open
    #     temp.path
    #   else
    #     uploader.file.file
    #   end
    # end

    def send_error_to_sentry(error, saved_claim_id)
      log_exception_to_sentry(
        error,
        {
          claim_id: saved_claim_id
        },
        { team: 'vfs-ebenefits' }
      )
    end
  end
end
