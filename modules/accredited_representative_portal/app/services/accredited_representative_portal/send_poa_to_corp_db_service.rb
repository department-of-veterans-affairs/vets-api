# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SendPoaToCorpDbService
    def self.call(poa_request)
      new(poa_request).call
    end

    def initialize(poa_request)
      @poa_request = poa_request
      @veteran_id  = poa_request.claimant.icn
      @service     = BenefitsClaims::Service.new(@veteran_id)
    end

    def call
      payload = build_payload
      @service.submit_power_of_attorney(payload)
    rescue => e
      log_error(e)
      raise
    end

    private

    def build_payload
      form_data = @poa_request.power_of_attorney_form.parsed_data
      veteran = form_data.fetch('veteran')
      address = veteran.fetch('address')
      authorizations = form_data.fetch('authorizations', {})
      phone_digits = (veteran['phone'] || '').gsub(/\D/, '')

      {
        data: {
          attributes: {
            veteran: {
              serviceNumber: veteran['serviceNumber'],
              serviceBranch: veteran['serviceBranch'],
              address: {
                addressLine1: address['addressLine1'],
                addressLine2: address['addressLine2'],
                city: address['city'],
                stateCode: address['stateCode'],
                zipCode: address['zipCode'],
                zipCodeSuffix: address['zipCodeSuffix'],
                countryCode: address['countryCode'] || 'US'
              },
              phone: {
                areaCode: phone_digits[0, 3],
                phoneNumber: phone_digits[3, 7]
              },
              email: veteran['email'],
              insuranceNumber: veteran['insuranceNumber']
            },
            representative: {
              poaCode: @poa_request.power_of_attorney_holder_poa_code
            },
            recordConsent: true,
            consentAddressChange: authorizations['addressChange'] == true,
            consentLimits: authorizations['recordDisclosureLimitations'] || []
          }
        }
      }
    end

    def log_error(error)
      Rails.logger.error(
        'POA CorpDB send failed',
        poa_request_id: @poa_request.id,
        error: error.class.name,
        message: error.message
      )
    end
  end
end

  