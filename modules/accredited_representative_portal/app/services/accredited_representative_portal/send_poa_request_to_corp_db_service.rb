# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SendPoaRequestToCorpDbService
    def self.call(poa_request)
      new(poa_request).call
    end

    def initialize(poa_request)
      @poa_request = poa_request
      @veteran_id  = poa_request.claimant.icn
      @service     = BenefitsClaims::Service.new(@veteran_id)
    end

    def call
      @service.submit_power_of_attorney_request(build_payload)
    rescue Faraday::Error => e
      log_error(e)
      raise
    end

    private

    def build_payload
      {
        data: {
          attributes: {
            veteran: veteran_payload,
            representative: representative_payload,
            recordConsent: authorizations['recordDisclosureLimitations'].blank?,
            consentAddressChange: authorizations['addressChange'] == true,
            consentLimits: authorizations['recordDisclosureLimitations'] || []
          }
        }
      }
    end

    def veteran_payload
      {
        serviceNumber: veteran['serviceNumber'],
        serviceBranch: veteran['serviceBranch'],
        address: address_payload,
        phone: phone_payload,
        email: veteran['email'],
        insuranceNumber: veteran['insuranceNumber']
      }
    end

    def address_payload
      {
        addressLine1: address['addressLine1'],
        addressLine2: address['addressLine2'],
        city: address['city'],
        stateCode: address['stateCode'],
        zipCode: address['zipCode'],
        zipCodeSuffix: address['zipCodeSuffix'],
        countryCode: address['countryCode'] || 'US'
      }
    end

    def phone_payload
      digits = (veteran['phone'] || '').gsub(/\D/, '')
      {
        areaCode: digits[0, 3],
        phoneNumber: digits[3, 7]
      }
    end

    def representative_payload
      { poaCode: @poa_request.power_of_attorney_holder_poa_code }
    end

    def form_data
      @form_data ||= @poa_request.power_of_attorney_form.parsed_data
    end

    def veteran
      @veteran ||= form_data.fetch('veteran')
    end

    def address
      @address ||= veteran.fetch('address')
    end

    def authorizations
      @authorizations ||= form_data.fetch('authorizations', {})
    end

    def log_error(error)
      Rails.logger.error(
        'POA CorpDB send failed',
        poa_request_id: @poa_request.id,
        error_class: error.class.name,
        status: error.respond_to?(:response) ? error.response&.[](:status) : nil
      )
    end
  end
end
