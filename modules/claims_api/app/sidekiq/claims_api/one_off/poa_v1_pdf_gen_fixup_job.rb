# frozen_string_literal: true

require 'claims_api/poa_vbms_sidekiq'
require 'claims_api/v1/poa_pdf_constructor/organization'
require 'claims_api/v1/poa_pdf_constructor/individual'
require 'claims_api/stamp_signature_error'
require 'bd/bd'

# This is a modified copy of V1::PoaFormBuilderJob that only regenerates & submits the PDF.
# It will not update the POA like the original job would.
module ClaimsApi
  module OneOff
    class PoaV1PdfGenFixupJob < ClaimsApi::ServiceBase
      include ClaimsApi::PoaVbmsSidekiq

      sidekiq_options retry: false

      LOG_TAG = 'poa_v1_pdf_gen_fixup_job'

      # Generate a 21-22 or 21-22a form for a given POA request.
      # Uploads the generated form to VBMS or BD.
      # @param power_of_attorney_id [String] Unique identifier of the submitted POA
      def perform(power_of_attorney_id)
        unless Flipper.enabled?(:claims_api_poa_v1_pdf_gen_fixup_job)
          ClaimsApi::Logger.log(LOG_TAG,
                                detail: "Skipping pdf re-upload of POA #{power_of_attorney_id}. Flipper disabled.")
          return
        end

        power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
        output_path = pdf_constructor.construct(data(power_of_attorney), id: power_of_attorney_id)
        benefits_doc_upload(poa: power_of_attorney, pdf_path: output_path, doc_type: 'L075', action: 'post')
        ClaimsApi::Logger.log LOG_TAG, detail: "POA #{power_of_attorney_id} PDF successfully regenerated & re-uploaded"
      rescue => e
        ClaimsApi::Logger.log LOG_TAG, level: :error,
                                       detail: "Exception thrown on POA #{power_of_attorney_id}",
                                       error_class: e.class.name
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

      def pdf_constructor
        ClaimsApi::V1::PoaPdfConstructor::Organization.new
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
