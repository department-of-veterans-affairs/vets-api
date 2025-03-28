# frozen_string_literal: true

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'financial-report'

      def create
        StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.initiated")
        digital_dispute = V0::DigitalDispute.new(digital_disputes_params, current_user)

        if digital_dispute.valid?
          # Just returning data back for now while we wait on our integration partner
          render json: digital_dispute.sanitized_json
        else
          StatsD.increment("#{V0::DigitalDispute::STATS_KEY}.failure")
          render json: { errors: digital_dispute.errors }, status: :unprocessable_entity
        end
      end

      private

      def mobile_phone
        %i[
          area_code
          country_code
          phone_number
          extension
          phone_type
          source_date
          source_system_user
          transaction_id
          vet360_id
          updated_at
          effective_start_date
          effective_end_date
          created_at
          id
          is_international is_textable is_text_permitted
          is_tty
          is_voicemailable
        ]
      end

      def address
        %i[ address_line1 address_line2 address_line3 address_pou
            address_type
            bad_address
            city
            country_code_fips country_code_iso2 country_code_iso3
            county_code country_name
            created_at
            effective_end_date effective_start_date
            id
            geocode_date geocode_precision
            international_postal_code
            latitude longitude
            province
            source_date source_system_user
            state_code
            transaction_id
            updated_at
            validation_key
            vet360_id
            zip_code zip_code_suffix]
      end

      def digital_disputes_params
        params.permit(
          selected_debts: %i[support_statement dispute_reason composite_debt_id label description debt_type
                             selected_debt_id],
          veteran_information: [:email,
                                {
                                  mobile_phone:,
                                  mailing_address: address
                                }]
        )
      end
    end
  end
end
