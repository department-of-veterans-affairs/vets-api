# frozen_string_literal: true

require_relative 'service'

module VRE
  class Ch31Form < VRE::Service
    configuration VRE::Configuration
    STATSD_KEY_PREFIX = 'api.vre'

    # The Ch31Form class is the means by which the Ch31 aka 28-1900 form is submitted to VR&E

    def initialize(user, claim)
      @user = user
      @claim = claim
      @parsed_form = @claim.parsed_form
    end

    # Submits prepared data derived from VeteranReadinessEmploymentClaim#form
    #
    # @return [Hash] the student's address
    #
    def submit
      response = send_to_vre(payload: format_payload_for_vre)

      response.body
    end

    private

    def format_payload_for_vre
      form_data = @parsed_form

      vre_payload = {
        data: {
          educationLevel: form_data['yearsOfEducation'],
          useEva: form_data['use_eva'],
          useTelecounseling: form_data['useTelecounseling'],
          meetingTime: form_data['appointmentTimePreferences'].key(true),
          isMoving: form_data['isMoving'],
          mainPhone: form_data['mainPhone'],
          cellPhone: form_data['cellPhone'],
          emailAddress: form_data['email']
        }
      }

      vre_payload[:data].merge!(veteran_address(form_data))
      vre_payload[:data].merge!({ veteranInformation: @parsed_form['veteranInformation'] })
      vre_payload[:data].merge!(new_address) if @parsed_form['newAddress'].present?

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

    def new_address
      new_address = @parsed_form['newAddress']
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
  end
end
