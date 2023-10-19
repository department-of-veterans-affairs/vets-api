# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'pdf_generator_service/pdf_client'
require 'bd/bd'
require 'claims_api/claim_logger'
require 'claims_api/vbms_uploader'
require 'claims_api/poa_vbms_sidekiq'

module ClaimsApi
  module V2
    class DisabilityCompensationVBMSUploader
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform(claim_id) # rubocop:disable Metrics/MethodLength
        ClaimsApi::Logger.log('********** 526 v2 VBMS Uploader job',
                              claim_id:,
                              detail: 'VBMS upload job started')

        claim_object = ClaimsApi::SupportingDocument.find_by(id: claim_id) ||
                       ClaimsApi::AutoEstablishedClaim.find_by(id: claim_id)

        auto_claim = claim_object.try(:auto_established_claim) || claim_object

        uploader = claim_object.uploader
        uploader.retrieve_from_store!(claim_object.file_data['filename'])
        file_body = uploader.read

        bd_upload_body(auto_claim:, file_body:)

        ClaimsApi::Logger.log('526 v2 VBMS Uploader job',
                              claim_id:,
                              detail: 'Uploaded 526EZ PDF to VBMS')

        start_claim_establsher_job(auto_claim) if auto_claim.status != 'errored'

        ClaimsApi::Logger.log('526 v2 VBMS Uploader job',
                              claim_id:,
                              detail: 'VBMS uploaded succeeded')

      # Temporary errors (returning HTML, connection timeout), retry call
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_errored_state(claim_id)
        ClaimsApi::Logger.log('526 v2 VBMS Uploader job',
                              claim_id:,
                              detail: "VBMS failure for claimId #{auto_claim&.id}: #{e.message}")
        raise e
      # Permanent failures, don't retry
      rescue VBMS::Unknown
        rescue_vbms_error(claim)
      rescue Errno::ENOENT
        rescue_file_not_found(claim)
        raise
      rescue VBMS::FilenumberDoesNotExist
        rescue_vbms_file_number_not_found(claim)
        raise
      rescue => e
        set_errored_state(claim_id)
        message = get_error_message(e)

        ClaimsApi::Logger.log('526 v2 VBMS Uploader job',
                              claim_id:,
                              detail: "VBMS failure for claimId #{auto_claim&.id}: #{message}")

        # {}
        raise e
      end

      private

      def set_errored_state(claim_id)
        auto_claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)

        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.save!
      end

      def get_error_message(e)
        if e.respond_to? :original_body
          e.original_body
        else
          e.message
        end
      end

      def start_claim_establsher_job(auto_claim)
        claim_establisher_service.new.perform(auto_claim&.id)
      end

      def claim_establisher_service
        ClaimsApi::V2::DisabilityCompensationClaimEstablisher
      end

      def bd_upload_body(auto_claim:, file_body:)
        fh = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
        begin
          fh.write(file_body)
          fh.close
          claim_bd_upload_document(auto_claim, fh.path)
        ensure
          fh.unlink
        end
      end

      def claim_bd_upload_document(claim, pdf_path)
        ClaimsApi::BD.new.upload(claim:, pdf_path:)
      end
    end
  end
end
