# frozen_string_literal: false

# rubocop:disable Metrics/ModuleLength
require 'claims_api/dependent_claimant_validation'

module ClaimsApi
  module V2
    module PowerOfAttorneyValidation
      include ClaimsApi::DependentClaimantValidation

      def validate_form_2122_and_2122a_submission_values(user_profile:, veteran_participant_id: nil,
                                                         poa_code: nil, base: nil)
        validate_non_claimant_address_values
        validate_claimant_fields(user_profile)
        if [veteran_participant_id, user_profile, poa_code, base].all?(&:present?)
          validate_dependent_claimant(veteran_participant_id:, user_profile:, poa_code:, base:)
        end

        # collect errors and pass back to the controller
        raise_error_collection if @errors
      end

      private

      def validate_dependent_claimant(veteran_participant_id:, user_profile:, poa_code:, base:)
        return nil unless allow_dependent_claimant?

        service = build_dependent_claimant_verification_service(veteran_participant_id:, user_profile:,
                                                                poa_code:)

        validate_claimant(service:, base:)
      end

      def build_dependent_claimant_verification_service(veteran_participant_id:, user_profile:, poa_code:)
        claimant = user_profile.profile

        ClaimsApi::DependentClaimantVerificationService.new(veteran_participant_id:,
                                                            claimant_first_name: claimant.given_names.first,
                                                            claimant_last_name: claimant.family_name,
                                                            claimant_participant_id: claimant.participant_id,
                                                            poa_code:)
      end

      def validate_non_claimant_address_values
        %w[veteran representative].each do |base|
          address = form_attributes.dig(base, 'address')

          validate_address_zip_code(address, base) if address.present?
        end
      end

      def validate_claimant(service:, base:)
        validate_poa_code(service:, base:)
        validate_dependent(service:)
      end

      def validate_poa_code(service:, base:)
        service.validate_poa_code_exists!
      rescue ::Common::Exceptions::UnprocessableEntity
        collect_error_messages(
          source: "/#{base}/poaCode",
          detail: ClaimsApi::DependentClaimantVerificationService::POA_CODE_NOT_FOUND_ERROR_MESSAGE
        )
      end

      def validate_dependent(service:)
        service.validate_dependent_by_participant_id!
      rescue ::Common::Exceptions::UnprocessableEntity
        collect_error_messages(
          source: '/claimant/claimantId',
          detail: ClaimsApi::DependentClaimantVerificationService::CLAIMANT_NOT_A_DEPENDENT_ERROR_MESSAGE
        )
      end

      def validate_claimant_fields(user_profile)
        return if form_attributes['claimant'].blank?

        validate_claimant_id_included(user_profile)
        validate_address
        validate_relationship
      end

      def validate_address
        address = form_attributes.dig('claimant', 'address')

        if address.nil?
          collect_error_messages(
            source: '/claimant/address/',
            detail: "If claimant is present 'address' must be filled in " \
                    "with required fields addressLine1, city, stateCode and countryCode. If the countryCode is 'US' " \
                    'then zipCode is also required.'
          )
        else
          validate_address_line_one(address)
          validate_address_city(address)
          validate_address_state_code(address)
          validate_address_country_code(address)
          validate_address_zip_code(address, 'claimant')
        end
      end

      def validate_address_line_one(address)
        if address['addressLine1'].nil?
          collect_error_messages(
            source: '/claimant/address/addressLine1',
            detail: "If claimant is present 'addressLine1' must be filled in"
          )
        end
      end

      def validate_address_city(address)
        if address['city'].nil?
          collect_error_messages(
            source: '/claimant/address/city',
            detail: "If claimant is present 'city' must be filled in"
          )
        end
      end

      def validate_address_state_code(address)
        if address['stateCode'].nil?
          collect_error_messages(
            source: '/claimant/address/stateCode',
            detail: "If claimant is present 'stateCode' must be filled in"
          )
        end
      end

      def validate_address_country_code(address)
        if address['countryCode'].nil?
          collect_error_messages(
            source: '/claimant/address/countryCode',
            detail: "If claimant is present 'countryCode' must be filled in"
          )
        end
      end

      def validate_address_zip_code(address, base)
        country = address['countryCode']&.downcase
        return unless country == 'us'

        if address['zipCode'].blank?
          collect_error_messages(
            source: "/#{base}/address/zipCode",
            detail: "If 'countryCode' is 'US' then 'zipCode' is required."
          )
        end
      end

      def validate_relationship
        relationship = form_attributes.dig('claimant', 'relationship')

        if relationship.nil?
          collect_error_messages(
            source: '/claimant/relationship/',
            detail: "If claimant is present 'relationship' must be filled in"
          )
        end
      end

      def validate_claimant_id_included(user_profile)
        claimant_icn = form_attributes.dig('claimant', 'claimantId')
        if (user_profile.blank? || user_profile&.status == :not_found) && claimant_icn
          collect_error_messages(
            source: 'claimant/claimantId',
            detail: "The 'claimantId' must be valid"
          )
        else
          address = form_attributes.dig('claimant', 'address')
          phone = form_attributes.dig('claimant', 'phone')
          relationship = form_attributes.dig('claimant', 'relationship')
          return if claimant_icn.present? && (address.present? || phone.present? || relationship.present?)

          collect_error_messages(
            source: '/claimant/claimantId/',
            detail: "If claimant is present 'claimantId' must be filled in"
          )
        end
      end

      def errors_array
        @errors ||= []
      end

      def collect_error_messages(detail: 'Missing or invalid attribute', source: '/',
                                 title: 'Unprocessable Entity', status: '422')
        errors_array.push({ detail:, source:, title:, status: })
      end

      def raise_error_collection
        errors_array.uniq! { |e| [e[:source], e[:detail]] }
        errors_array
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
