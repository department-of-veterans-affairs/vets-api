# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/poa_vbms_sidekiq'
require 'claims_api/poa_pdf_constructor/organization'
require 'claims_api/poa_pdf_constructor/individual'
require_dependency 'claims_api/stamp_signature_error'

module ClaimsApi
  class PoaFormBuilderJob
    include Sidekiq::Worker
    include ClaimsApi::PoaVbmsSidekiq

    # Generate a 21-22 or 21-22a form for a given POA request.
    # Uploads the generated form to VBMS. If successfully uploaded,
    # it queues a job to update the POA code in BGS, as well.
    #
    # @param power_of_attorney_id [String] Unique identifier of the submitted POA
    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      poa_code = power_of_attorney.form_data['serviceOrganization']['poaCode']

      output_path = pdf_constructor(poa_code).construct(data(power_of_attorney), id: power_of_attorney.id)

      upload_to_vbms(power_of_attorney, output_path)
      ClaimsApi::PoaUpdater.perform_async(power_of_attorney.id)
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
    rescue ClaimsApi::StampSignatureError => e
      signature_errors = (power_of_attorney.signature_errors || []).push(e.detail)
      power_of_attorney.update(status: ClaimsApi::PowerOfAttorney::ERRORED, signature_errors:)
    end

    def pdf_constructor(poa_code)
      if poa_code_in_organization?(poa_code)
        ClaimsApi::PoaPdfConstructor::Organization.new
      else
        ClaimsApi::PoaPdfConstructor::Individual.new
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
      ::Veteran::Service::Organization.find_by(poa: poa_code).present?
    end
  end
end
