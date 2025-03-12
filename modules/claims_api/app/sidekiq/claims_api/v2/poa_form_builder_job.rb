# frozen_string_literal: true

require 'claims_api/poa_vbms_sidekiq'
require 'claims_api/v2/poa_pdf_constructor/organization'
require 'claims_api/v2/poa_pdf_constructor/individual'
require 'claims_api/stamp_signature_error'
require 'bd/bd'

module ClaimsApi
  module V2
    class PoaFormBuilderJob < ClaimsApi::ServiceBase
      include ClaimsApi::PoaVbmsSidekiq

      sidekiq_options retry_for: 48.hours

      # Generate a 21-22 or 21-22a form for a given POA request.
      # Uploads the generated form to VBMS. If successfully uploaded,
      # it queues a job to update the POA code in BGS, as well.
      #
      # @param power_of_attorney_id [String] Unique identifier of the submitted POA
      def perform(power_of_attorney_id, form_number, action, rep_id) # rubocop:disable Metrics/MethodLength
        power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)

        process = ClaimsApi::Process.find_or_create_by(processable: power_of_attorney,
                                                       step_type: 'PDF_SUBMISSION')
        process.update!(step_status: 'IN_PROGRESS')

        rep = ::Veteran::Service::Representative.where(representative_id: rep_id).order(created_at: :desc).first

        output_path = pdf_constructor(form_number).construct(data(power_of_attorney, form_number, rep),
                                                             id: power_of_attorney.id)
        power_of_attorney.form_data.dig('serviceOrganization', 'poaCode')

        if Flipper.enabled?(:lighthouse_claims_api_poa_use_bd)
          doc_type = form_number == '2122' ? 'L190' : 'L075'
          benefits_doc_upload(poa: power_of_attorney, pdf_path: output_path, doc_type:, action:)
        else
          upload_to_vbms(power_of_attorney, output_path)
        end

        if dependent_filing?(power_of_attorney)
          ClaimsApi::PoaAssignDependentClaimantJob.perform_async(power_of_attorney.id, rep_id)
        else
          ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id, rep_id)
        end
        process.update!(step_status: 'SUCCESS', error_messages: [], completed_at: Time.zone.now)
      rescue VBMS::Unknown
        rescue_vbms_error(power_of_attorney, process:)
      rescue Errno::ENOENT
        rescue_file_not_found(power_of_attorney, process:)
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

      def pdf_constructor(form_number)
        if form_number == '2122A'
          ClaimsApi::V2::PoaPdfConstructor::Individual.new
        else
          ClaimsApi::V2::PoaPdfConstructor::Organization.new
        end
      end

      #
      # Combine form_data with auth_headers and signature data
      #
      # @param power_of_attorney [ClaimsApi::PowerOfAttorney] Record for this poa change request
      # @param form_number [String] Either 2122 or 2122A
      #
      # @return [Hash] All data to be inserted into pdf
      def data(power_of_attorney, form_number, rep)
        res = power_of_attorney.form_data
        res.deep_merge!(veteran_attributes(power_of_attorney))
        res.deep_merge!(appointment_date(power_of_attorney))

        signatures = if form_number == '2122A'
                       individual_signatures(power_of_attorney, rep)
                     else
                       organization_signatures(power_of_attorney, rep)
                     end

        res.deep_merge!({ (form_number == '2122A' ? 'representative' : 'serviceOrganization') => {
                          'firstName' => rep.first_name,
                          'lastName' => rep.last_name
                        } })

        res.deep_merge!(organization_name(power_of_attorney)) if form_number == '2122'

        res.merge!({ 'text_signatures' => signatures })
        res
      end

      def appointment_date(power_of_attorney)
        {
          'appointmentDate' => power_of_attorney.created_at
        }
      end

      def veteran_attributes(power_of_attorney)
        {
          'veteran' => {
            'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
            'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
            'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
            'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
          }
        }
      end

      def organization_signatures(power_of_attorney, rep)
        first_name, last_name = veteran_or_claimant_signature(power_of_attorney)
        {
          'page2' => [
            {
              'signature' => "#{first_name} " \
                             "#{last_name} - signed via api.va.gov",
              'x' => 35,
              'y' => 240
            },
            {
              'signature' => "#{rep.first_name} #{rep.last_name} - signed via api.va.gov",
              'x' => 35,
              'y' => 200
            }
          ]
        }
      end

      def individual_signatures(power_of_attorney, rep)
        first_name, last_name = veteran_or_claimant_signature(power_of_attorney)
        {
          'page2' => [
            {
              'signature' => "#{first_name} #{last_name} - signed via api.va.gov",
              'x' => 35,
              'y' => 306
            },
            {
              'signature' => "#{rep.first_name} #{rep.last_name} - signed via api.va.gov",
              'x' => 35,
              'y' => 200
            }
          ]
        }
      end

      def veteran_or_claimant_signature(power_of_attorney)
        claimant = power_of_attorney.form_data['claimant'].present?
        if claimant
          first_name = power_of_attorney.form_data['claimant']['firstName']
          last_name = power_of_attorney.form_data['claimant']['lastName']
        else
          first_name = power_of_attorney.auth_headers['va_eauth_firstName']
          last_name = power_of_attorney.auth_headers['va_eauth_lastName']
        end
        [first_name, last_name]
      end

      def organization_name(power_of_attorney)
        poa_code = power_of_attorney.form_data.dig('serviceOrganization', 'poaCode')

        name = ::Veteran::Service::Organization.find_by(poa: poa_code).name

        {
          'serviceOrganization' => {
            'organizationName' => name
          }
        }
      end
    end
  end
end
