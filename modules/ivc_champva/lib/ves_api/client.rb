# frozen_string_literal: true

require 'json'
require 'common/client/base'
require_relative 'configuration'

module IvcChampva
  module VesApi
    class VesApiError < StandardError; end

    # TODO: define Message response structure

    class Client < Common::Client::Base
      configuration IvcChampva::VesApi::Configuration

      ##
      # HTTP POST call to the VES VFMP CHAMPVA Application service to submit a 10-10d application.
      #
      # @param transaction_uuid [string] the UUID for the application
      # @param acting_user [string, nil] the acting user for the application
      # @param parsed_form_data [hash] form data from frontend to send to VES
      # @return [Array<Message>] the report rows
      def submit_1010d(transaction_uuid, acting_user, parsed_form_data)
        connection.post("#{config.base_path}/champva-applications") do |req|
          req.headers = headers(transaction_uuid, acting_user)
          req.body = convert_to_champva_application(parsed_form_data).to_json
        end

        # TODO: check for non-200 responses and handle them appropriately

        # TODO: parse and return response messages, if we have a use for them?
      rescue => e
        raise VesApiError, e.message.to_s
      end

      ##
      # Assembles headers for the VES API request
      #
      # @param transaction_uuid [string] the start date of the report
      # @param acting_user [string, nil] the end date of the report
      # @return [Hash] the headers
      def headers(transaction_uuid, acting_user)
        {
          :content_type => 'application/json',
          # 'apiKey' => Settings.ivc_champva.ves_api.api_key.to_s,
          'apiKey' => 'fake-api-key',
          'transactionUUId' => transaction_uuid.to_s,
          'acting-user' => acting_user.to_s
        }
      end

      private

      ##
      # Maps an address property received from the frontend into the structure
      # required by VES. Adds "NA" strings to properties with no value.
      #
      # @param source_address [hash] Address object as received from the frontend
      # @return [hash|nil] TODO: possibly throw an error instead of returning nil?
      #
      def map_address_to_ves_fmt(source_address)
        # Ensure the source address is properly structured before mapping
        return nil unless source_address.is_a?(Hash)

        {
          'streetAddress' => (source_address['street_combined'] || source_address['street']) || 'NA',
          'city' => source_address['city'] || 'NA',
          'state' => source_address['state'] || 'NA',
          'zipCode' => source_address['postal_code'] || 'NA'
        }
      end

      ##
      # Converts the processed form data received from the frontend into the structure
      # required by VES.
      #
      # @param processed_form_data [hash] form data received from the frontend
      #
      def convert_to_champva_application(processed_form_data)
        # TODO: parsed_form_data is currently not exactly compatible with VES.
        # the following still need to be addressed in addition to the mapping below:
        # - Dates: must be YYYY-MM-DD
        # - Phones: Must be (123) 123-1234
        # - Gender must match expected values e.g. "MALE"/"FEMALE" in all caps
        # - Relationship to vet must match expected values e.g. "CHILD", "CAREGIVER", "SPOUSE", "EX_SPOUSE"
        # - For beneficiaries/applicants that are sponsor's child, must have `childType` e.g., "ADOPTED", "NATURAL", "STEPCHILD"

        # TODO: add safety to this/default values or possibly throw errors based
        # on certain missing values.
        {
          'applicationType' => 'some_application_type',  # TODO: 10-10d
          'applicationUUID' => 'some_unique_uuid',       # TODO: generate appropriate UUID
          'sponsor' => {
            'personUUID' => 'some_unique_uuid', # TODO: generate appropriate UUID
            'firstName' => processed_form_data['veteran']['full_name']['first'],
            'lastName' => processed_form_data['veteran']['full_name']['last'],
            'middleInitial' => processed_form_data['veteran']['full_name']['middle'],
            'ssn' => processed_form_data['veteran']['ssn_or_tin'],
            'vaFileNumber' => processed_form_data['veteran']['va_claim_number'],
            'dateOfBirth' => processed_form_data['veteran']['date_of_birth'],
            'dateOfMarriage' => processed_form_data['veteran']['date_of_marriage'],
            'isDeceased' => processed_form_data['veteran']['sponsor_is_deceased'],
            'dateOfDeath' => processed_form_data['veteran']['date_of_death'],
            'isDeathOnActiveService' => processed_form_data['veteran']['is_active_service_death'],
            'address' => map_address_to_ves_fmt(processed_form_data['veteran']['address'])
          },
          'beneficiaries' => processed_form_data['applicants'].map do |applicant|
            {
              'personUUID' => 'some_unique_uuid', # TODO: generate appropriate UUID
              'firstName' => applicant['applicant_name']['first'],
              'lastName' => applicant['applicant_name']['last'],
              'middleInitial' => applicant['applicant_name']['middle'],
              'ssn' => applicant['ssn_or_tin'],
              'emailAddress' => applicant['applicant_email_address'],
              'phoneNumber' => applicant['applicant_phone'],
              'gender' => applicant['applicant_gender']['gender'],
              'enrolledInMedicare' => applicant['applicant_medicare_status']['eligibility'] == 'enrolled',
              'hasOtherInsurance' => applicant['applicant_has_ohi']['has_ohi'] == 'yes',
              'relationshipToSponsor' => applicant['vet_relationship'],
              'childtype' => applicant['childtype'],
              'address' => map_address_to_ves_fmt(applicant['applicant_address']),
              'dateOfBirth' => applicant['applicant_dob']
            }
          end,
          'certification' => {
            'signature' => processed_form_data['statement_of_truth_signature'],
            'signatureDate' => processed_form_data['certification']['date'],
            'firstName' => processed_form_data['certification']['first_name'],
            'lastName' => processed_form_data['certification']['last_name'],
            'middleInitial' => processed_form_data['certification']['middle_initial'],
            'phoneNumber' => processed_form_data['certification']['phone_number']
          }
        }
      end
    end
  end
end
