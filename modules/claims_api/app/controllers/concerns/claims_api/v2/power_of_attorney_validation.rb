# frozen_string_literal: false

module ClaimsApi
  module V2
    module PowerOfAttorneyValidation
      def validate_form_2122_and_2122a_submission_values
        validate_claimant
        # collect errors and pass back to the controller
        raise_error_collection if @errors
      end

      private

      def validate_claimant
        return if form_attributes['claimant'].blank?

        validate_claimant_id_included
        validate_address
        validate_relationship
      end

      def validate_address
        address = form_attributes.dig('claimant', 'address')

        if address.nil?
          collect_error_messages(
            source: '/claimant/address/',
            detail: "If claimant is present 'address' must be filled in " \
                    ' with required fields addressLine1, city, stateCode, country and zipCode'
          )
        else
          validate_address_line_one(address)
          validate_address_city(address)
          validate_address_state_code(address)
          validate_address_country(address)
          validate_address_zip_code(address)
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

      def validate_address_country(address)
        if address['country'].nil?
          collect_error_messages(
            source: '/claimant/address/country',
            detail: "If claimant is present 'country' must be filled in"
          )
        end
      end

      def validate_address_zip_code(address)
        if address['zipCode'].nil?
          collect_error_messages(
            source: '/claimant/address/zipCode',
            detail: "If claimant is present 'zipCode' must be filled in"
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

      def validate_claimant_id_included
        claimant_icn = form_attributes.dig('claimant', 'claimantId')
        check_claimant_id_found(claimant_icn)

        address = form_attributes.dig('claimant', 'address')
        phone = form_attributes.dig('claimant', 'phone')
        relationship = form_attributes.dig('claimant', 'relationship')
        return if claimant_icn.present? && (address.present? || phone.present? || relationship.present?)

        collect_error_messages(
          source: '/claimant/claimantId/',
          detail: "If claimant is present 'claimantId' must be filled in"
        )
      end

      def check_claimant_id_found(claimant_icn)
        user_profile = mpi_service.find_profile_by_identifier(identifier: claimant_icn,
                                                              identifier_type: MPI::Constants::ICN)
        return if user_profile

        collect_error_messages(
          source: 'claimant/claimantId',
          detail: "The 'claimantId' must be valid"
        )
      rescue ArgumentError
        collect_error_messages(
          source: 'claimant/claimantId',
          detail: "The 'claimantId' must be valid"
        )
      end

      def errors_array
        @errors ||= []
      end

      def collect_error_messages(detail: 'Missing or invalid attribute', source: '/',
                                 title: 'Unprocessable Entity', status: '422')

        errors_array.push({ detail:, source:, title:, status: })
      end

      def raise_error_collection
        errors_array.uniq! { |e| e[:detail] }
        errors_array
      end
    end
  end
end
