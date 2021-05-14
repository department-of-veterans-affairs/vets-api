# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/vbms_sidekiq'
require 'claims_api/poa_pdf_constructor/organization'
require 'claims_api/poa_pdf_constructor/individual'
require_dependency 'claims_api/stamp_signature_error'

module ClaimsApi
  class PoaFormBuilderJob
    include Sidekiq::Worker
    include ClaimsApi::VBMSSidekiq

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      representative = "TODO: Find by poa code?"

      output_path = pdf_constructor(representative).construct(data(power_of_attorney), id: power_of_attorney.id)
      
      upload_to_vbms(power_of_attorney, output_path)
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
    rescue ClaimsApi::StampSignatureError => e
      power_of_attorney.update(signature_errors: e.detail)
    end

    def pdf_constructor(representative)
      return ClaimsApi::PoaPdfConstructor::Organization.new if poa_in_organization?(representative)

      ClaimsApi::PoaPdfConstructor::Individual.new
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

    def poa_in_organization?(representative)
      # TODO: determine based on rep type
      true
    end
  end
end
