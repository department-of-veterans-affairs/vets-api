# frozen_string_literal: true

require_relative 'service'
require_relative 'errors/ch31_errors'
require 'sentry_logging'

module RES
  class Ch31Form < RES::Service
    include SentryLogging
    configuration RES::Configuration
    STATSD_KEY_PREFIX = 'api.res'

    def initialize(user:, claim:)
      super()
      @user = user
      @claim = claim
    end

    # Submits prepared data derived from VeteranReadinessEmploymentClaim#form
    #
    # @return [Hash] the student's address
    #
    def submit
      if @claim.nil?
        Rails.logger.error('Ch31NilClaimError. user icn:', @user.icn)
        raise Ch31NilClaimError
      end

      response = send_to_res(payload: format_payload_for_res)
      response_body = response.body

      raise Ch31Error if response_body['success_message'].blank?

      response_body
    rescue Ch31Error => e
      process_ch_31_error(e, response_body)

      raise
    end

    private

    def format_payload_for_res
      form_data = claim_form_hash

      res_payload = {
        useEva: form_data['useEva'],
        receiveElectronicCommunication: form_data['receiveElectronicCommunication'],
        useTelecounseling: form_data['useTelecounseling'],
        appointmentTimePreferences: form_data['appointmentTimePreferences'],
        yearsOfEducation: form_data['yearsOfEducation'],
        isMoving: form_data['isMoving'],
        mainPhone: form_data['mainPhone'],
        cellNumber: form_data['cellPhone'],
        internationalNumber: form_data['internationalNumber'],
        email: form_data['email'],
        documentId: form_data['documentId'],
        receivedDate: @claim.created_at.iso8601, # e.g. "2024-12-02T17:36:52Z"
        veteranAddress: mapped_address_hash(form_data['veteranAddress'])
      }

      res_payload.merge!({ veteranInformation: adjusted_veteran_information })
      res_payload.merge!(new_address) if form_data['newAddress'].present?

      res_payload.to_json
    end

    # TODO: determine need
    def veteran_address(form_data)
      vet_address = mapped_address_hash(form_data['veteranAddress'])

      adjusted_address = {
        veteranAddress: vet_address
      }

      return adjusted_address if adjusted_address.dig(:veteranAddress, :isForeign) == false

      # RES/CMSA expects different keys for postal and state for foreign addresses
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
      vet_info['regionalOffice'] = vet_info['regionalOfficeName']
      vet_info.delete(:regionalOfficeName)

      vet_info
    end

    def new_address
      new_address = mapped_address_hash(claim_form_hash['newAddress'])

      adjusted_new_address = {
        newAddress: new_address
      }

      return adjusted_new_address unless new_address[:isForeign]

      # RES/CMSA expects different keys for postal and state for foreign addresses
      new_address[:internationalPostalCode] = new_address.delete(:zipCode)
      new_address[:province] = new_address.delete(:stateCode)

      adjusted_new_address
    end

    def mapped_address_hash(client_hash)
      {
        country: client_hash['country'],
        street: client_hash['street'],
        city: client_hash['city'],
        state: client_hash['state'],
        postalCode: client_hash['postalCode']
      }
    end

    def process_ch_31_error(e, response_body)
      Rails.logger.error(e)
      Rails.logger.error({
                           intake_id: response_body['ApplicationIntake'],
                           error_message: response_body['ErrorMessage']
                         })
    end
  end
end
