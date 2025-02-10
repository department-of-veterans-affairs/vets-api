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
          'apiKey' => 'fake_api_key', # TODO: Settings.ivc_champva.ves_api.api_key.to_s,
          'transactionUUId' => transaction_uuid.to_s,
          'acting-user' => acting_user.to_s
        }
      end

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
      # Converts the parsed form data received from the frontend into the structure
      # required by VES.
      #
      # @param parsed_form_data [hash] form data received from the frontend
      #
      def convert_to_champva_application(parsed_form_data)
        # TODO: parsed_form_data is currently not exactly compatible with VES.
        # the following still need to be addressed upstream in addition to the mapping below:
        # - Dates: must be YYYY-MM-DD
        # - Phones: Must be (123) 123-1234
        # - Gender must match expected values e.g. "MALE"/"FEMALE" in all caps
        # - Relationship to vet must match expected values e.g. "CHILD", "CAREGIVER", "SPOUSE", "EX_SPOUSE"
        # - For beneficiaries/applicants that are sponsor's child, must have `childType` e.g., "ADOPTED",
        #   "NATURAL", "STEPCHILD"

        # TODO: add safety to this/default values or possibly throw errors based
        # on certain missing values.

        # Initialize the result hash
        result = {}

        # Set applicationType and UUID
        result['applicationType'] = 'vha_10_10d' # TODO: verify this is correct
        result['applicationUUID'] = SecureRandom.uuid # TODO: determine how we want to generate/track these

        # Map veteran data using a helper method
        result['sponsor'] = map_veteran(parsed_form_data['veteran'])

        # Map applicant data
        result['beneficiaries'] = parsed_form_data['applicants'].map { |applicant| map_applicant(applicant) }

        # Map certification data
        result['certification'] = map_certification(
          parsed_form_data['certification'],
          parsed_form_data['statement_of_truth_signature']
        )

        result
      end

      private

      def map_veteran(veteran_data)
        {
          'personUUID' => SecureRandom.uuid, # TODO: determine how we want to generate/track these
          'firstName' => veteran_data.dig('full_name', 'first'),
          'lastName' => veteran_data.dig('full_name', 'last'),
          'ssn' => veteran_data['ssn_or_tin'],
          'dateOfBirth' => veteran_data['date_of_birth'],
          'isDeceased' => veteran_data['sponsor_is_deceased'],
          'dateOfDeath' => veteran_data['date_of_death'],
          'address' => map_address_to_ves_fmt(veteran_data['address'])
        }
      end

      def map_applicant(applicant_data)
        {
          'personUUID' => SecureRandom.uuid, # TODO: determine how we want to generate/track these
          'firstName' => applicant_data.dig('applicant_name', 'first'),
          'middleInitial' => applicant_data.dig('applicant_name', 'middle'),
          'lastName' => applicant_data.dig('applicant_name', 'last'),
          'ssn' => applicant_data.dig('applicant_ssn', 'ssn'),
          'emailAddress' => applicant_data['applicant_email_address'],
          'phoneNumber' => applicant_data['applicant_phone'],
          'gender' => applicant_data.dig('applicant_gender', 'gender'),
          'relationshipToSponsor' => applicant_data.dig('applicant_relationship_to_sponsor', 'relationship_to_veteran'),
          'vetRelationship' => applicant_data['vet_relationship'],
          'childtype' => applicant_data.dig('childtype', 'relationship_to_veteran'),
          'address' => map_address_to_ves_fmt(applicant_data['applicant_address']),
          'dateOfBirth' => applicant_data['applicant_dob'],
          'enrolledInMedicare' => applicant_data.dig('applicant_medicare_status', 'eligibility') == 'enrolled',
          'hasOtherInsurance' => applicant_data.dig('applicant_has_ohi', 'has_ohi') == 'yes',
          'supportingDocuments' => applicant_data['applicant_supporting_documents'] || []
        }
      end

      def map_certification(certification_data, signature)
        {
          'signature' => signature,
          'signatureDate' => certification_data['date'],
          'firstName' => certification_data['first_name'],
          'lastName' => certification_data['last_name'],
          'middleInitial' => certification_data['middle_initial'],
          'phoneNumber' => certification_data['phone_number']
        }
      end
    end
  end
end
