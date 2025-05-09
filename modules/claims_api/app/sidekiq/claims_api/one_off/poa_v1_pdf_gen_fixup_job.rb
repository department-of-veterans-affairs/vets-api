# frozen_string_literal: true

require 'claims_api/poa_vbms_sidekiq'
require 'claims_api/v1/poa_pdf_constructor/organization'
require 'claims_api/v1/poa_pdf_constructor/individual'
require 'claims_api/stamp_signature_error'
require 'bd/bd'

module ClaimsApi
  module OneOff
    class PoaV1PdfGenFixupJob < ClaimsApi::ServiceBase
      include ClaimsApi::PoaVbmsSidekiq

      sidekiq_options retry: false

      LOG_TAG = 'poa_v1_pdf_gen_fixup_job'

      # Generate a 21-22 or 21-22a form for a given POA request.
      # Uploads the generated form to VBMS or BD.
      # @param power_of_attorney_id [String] Unique identifier of the submitted POA
      def perform(power_of_attorney_id, action = 'post', form_number = nil) # rubocop:disable Metrics/MethodLength
        unless Flipper.enabled?(:claims_api_poa_v1_pdf_gen_fixup_job)
          ClaimsApi::Logger.log(LOG_TAG,
                                detail: "Skipping pdf re-upload of POA #{power_of_attorney_id}. Flipper disabled.")
          return
        end

        power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
        rep_or_org = form_number == '2122A' ? 'representative' : 'serviceOrganization'
        poa_code = power_of_attorney.form_data&.dig(rep_or_org, 'poaCode')

        output_path = pdf_constructor(poa_code).construct(data(power_of_attorney), id: power_of_attorney.id)

        if Flipper.enabled?(:lighthouse_claims_api_poa_use_bd)
          doc_type = form_number == '2122' ? 'L190' : 'L075'
          benefits_doc_upload(poa: power_of_attorney, pdf_path: output_path, doc_type:, action:)
        else
          upload_to_vbms(power_of_attorney, output_path)
        end
      rescue VBMS::Unknown
        rescue_vbms_error(power_of_attorney)
      rescue Errno::ENOENT
        rescue_file_not_found(power_of_attorney)
      rescue ClaimsApi::StampSignatureError => e
        signature_errors = (power_of_attorney.signature_errors || []).push(e.detail)
        power_of_attorney.update(status: ClaimsApi::PowerOfAttorney::ERRORED, signature_errors:)
        ClaimsApi::Logger.log(LOG_TAG, poa_id: power_of_attorney_id, detail: 'Prawn Signature Error')
      rescue => e
        rescue_generic_errors(power_of_attorney, e)
        raise
      end

      private

      def benefits_doc_api
        ClaimsApi::BD.new
      end

      def benefits_doc_upload(poa:, pdf_path:, doc_type:, action:)
        if Flipper.enabled?(:claims_api_poa_uploads_bd_refactor)
          PoaDocumentService.new.create_upload(poa:, pdf_path:, doc_type:, action:)
        else
          benefits_doc_api.upload(claim: poa, pdf_path:, doc_type:)
        end
      end

      def pdf_constructor(poa_code)
        if poa_code_in_organization?(poa_code)
          ClaimsApi::V1::PoaPdfConstructor::Organization.new
        else
          ClaimsApi::V1::PoaPdfConstructor::Individual.new
        end
      end

      #
      # Combine form_data with auth_headers
      #
      # @param power_of_attorney [ClaimsApi::PowerOfAttorney] Record for this poa change request
      #
      # @return [Hash] All data to be inserted into pdf
      def data(power_of_attorney)
        power_of_attorney.form_data.deep_merge({
                                                 'veteran' => {
                                                   'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
                                                   'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
                                                   'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
                                                   'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
                                                 }
                                               })
      end

      def poa_code_in_organization?(poa_code)
        ::Veteran::Service::Organization.exists?(poa: poa_code)
      end
    end
  end
end
