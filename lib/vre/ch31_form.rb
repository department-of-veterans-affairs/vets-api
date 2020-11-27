# frozen_string_literal: true

require_relative 'service'
require_relative 'errors/ch31_errors'
require 'sentry_logging'

# The Ch31Form class is the means by which the Ch31 aka 28-1900 form is submitted to VR&E
module VRE
  class Ch31Form < VRE::Service
    include SentryLogging
    configuration VRE::Configuration
    STATSD_KEY_PREFIX = 'api.vre'
    SENTRY_TAG = { team: 'vfs-ebenefits' }

    def initialize(user:, claim:)
      @user = user
      @claim = claim
    end

    # Submits prepared data derived from VeteranReadinessEmploymentClaim#form
    #
    # @return [Hash] the student's address
    #
    def submit
      raise Ch31NilClaimError if @claim.nil?

      response = send_to_vre(payload: format_payload_for_vre)
      response_body = response.body

      raise Ch31Error if response_body['error_occurred'] == true

      log_message_to_sentry(
        'Temp message for testing',
        :warn,
        {application_intake_id: response_body['application_intake']},
        SENTRY_TAG
      )
      response_body
    rescue Ch31Error => e
      process_ch_31_error(e, response_body)

      response_body
    rescue Ch31NilClaimError => e
      process_nil_claim_error(e)
    end

    private

    def format_payload_for_vre
      form_data = claim_form_hash

      vre_payload = {
        data: {
          educationLevel: form_data['yearsOfEducation'],
          useEva: form_data['useEva'],
          useTelecounseling: form_data['useTelecounseling'],
          meetingTime: form_data['appointmentTimePreferences'].key(true),
          isMoving: form_data['isMoving'],
          mainPhone: form_data['mainPhone'],
          cellPhone: form_data['cellPhone'],
          emailAddress: form_data['email']
        }
      }

      vre_payload[:data].merge!(veteran_address(form_data))
      vre_payload[:data].merge!({ veteranInformation: claim_form_hash['veteranInformation'] })
      vre_payload[:data].merge!(new_address) if claim_form_hash['newAddress'].present?

      vre_payload.to_json
    end

    def veteran_address(form_data)
      vet_address = form_data['veteranAddress']

      {
        veteranAddress: {
          isForeign: vet_address['country'] != 'USA',
          isMilitary: vet_address['isMilitary'] || false,
          countryName: vet_address['country'],
          addressLine1: vet_address['street'],
          addressLine2: vet_address['street2'],
          addressLine3: vet_address['street3'],
          city: vet_address['city'],
          stateCode: vet_address['state'],
          zipCode: vet_address['postalCode']
        }
      }
    end

    def claim_form_hash
      @claim.parsed_form
    end

    def new_address
      new_address = claim_form_hash['newAddress']
      {
        "newAddress": {
          "isForeign": new_address['country'] != 'USA',
          "isMilitary": new_address['isMilitary'],
          "countryName": new_address['country'],
          "addressLine1": new_address['street'],
          "addressLine2": new_address['street2'],
          "addressLine3": new_address['street3'],
          "city": new_address['city'],
          "province": new_address['state'],
          "internationalPostalCode": new_address['postalCode']
        }
      }
    end

    def process_ch_31_error(e, response_body)
      log_exception_to_sentry(
        e,
        {
          intake_id: response_body['ApplicationIntake'],
          error_message: response_body['ErrorMessage']
        },
        SENTRY_TAG
      )
    end

    def process_nil_claim_error(e)
      log_exception_to_sentry(
        e,
        {
          icn: @user.icn
        },
        SENTRY_TAG
      )

      { 'error_occurred' => true, 'error_message' => 'Claim cannot be null' }
    end
  end
end
