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
    SENTRY_TAG = { team: 'vfs-ebenefits' }.freeze

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
        { application_intake_id: response_body['application_intake'] },
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
          meetingTime: form_data['appointmentTimePreferences'],
          isMoving: form_data['isMoving'],
          mainPhone: form_data['mainPhone'],
          cellPhone: form_data['cellPhone'],
          emailAddress: form_data['email']
        }
      }

      vre_payload[:data].merge!(veteran_address(form_data))
      vre_payload[:data].merge!({ veteranInformation: adjusted_veteran_information })
      vre_payload[:data].merge!(new_address) if claim_form_hash['newAddress'].present?

      vre_payload.to_json
    end

    def veteran_address(form_data)
      vet_address = mapped_address_hash(form_data['veteranAddress'])

      adjusted_address = {
        veteranAddress: vet_address
      }

      return adjusted_address if adjusted_address.dig(:veteranAddress, :isForeign) == false

      # VRE/CMSA expects different keys for postal and state for foreign addresses
      # internationPostalCode misspelling is correct
      international_address = adjusted_address[:veteranAddress]
      international_address[:internationPostalCode] = international_address.delete(:zipCode)
      international_address[:province] = international_address.delete(:stateCode)

      adjusted_address
    end

    def claim_form_hash
      @claim.parsed_form
    end

    def adjusted_veteran_information
      vet_info = claim_form_hash['veteranInformation']

      vet_info['VAFileNumber'] = vet_info.delete('vaFileNumber') if vet_info.key?('vaFileNumber')

      vet_info
    end

    def new_address
      new_address = mapped_address_hash(claim_form_hash['newAddress'])

      adjusted_new_address = {
        newAddress: new_address
      }

      return adjusted_new_address unless new_address[:isForeign]

      # VRE/CMSA expects different keys for postal and state for foreign addresses
      new_address[:internationalPostalCode] = new_address.delete(:zipCode)
      new_address[:province] = new_address.delete(:stateCode)

      adjusted_new_address
    end

    def mapped_address_hash(client_hash)
      {
        isForeign: client_hash['country'] != 'USA',
        isMilitary: client_hash['isMilitary'] || false,
        countryName: client_hash['country'],
        addressLine1: client_hash['street'],
        addressLine2: client_hash['street2'],
        addressLine3: client_hash['street3'],
        city: client_hash['city'],
        stateCode: client_hash['state'],
        zipCode: client_hash['postalCode']
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
