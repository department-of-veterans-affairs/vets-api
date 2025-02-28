# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PowerOfAttorneyRequestBaseController < ApplicationController
      service_tag 'representation-management'
      before_action :feature_enabled

      private

      def params_permitted
        [
          :representative_submission_method,
          :record_consent,
          :consent_address_change,
          :consent_inside_access,
          :consent_outside_access,
          { consent_limits: [],
            consent_team_members: [],
            claimant: claimant_params_permitted,
            representative: representative_params_permitted,
            veteran: veteran_params_permitted }
        ]
      end

      def claimant_params_permitted
        [
          :date_of_birth,
          :relationship,
          :phone,
          :email,
          { name: name_params_permitted,
            address: address_params_permitted }
        ]
      end

      def representative_params_permitted
        [
          :organization_id,
          :id,
          :type,
          :phone,
          :email,
          { name: name_params_permitted,
            address: address_params_permitted }
        ]
      end

      def veteran_params_permitted
        [
          :ssn,
          :va_file_number,
          :date_of_birth,
          :service_number,
          :service_branch,
          :phone,
          :email,
          {
            name: name_params_permitted,
            address: address_params_permitted
          }
        ]
      end

      def flatten_claimant_params(claimant_params)
        claimant = claimant_params[:claimant]
        return {} if claimant.nil?

        address = claimant[:address]
        country_code = normalize_country_code_to_alpha2(address[:country])
        {
          claimant_first_name: claimant.dig(:name, :first),
          claimant_middle_initial: claimant.dig(:name, :middle)&.chr,
          claimant_last_name: claimant.dig(:name, :last),
          claimant_date_of_birth: claimant[:date_of_birth],
          claimant_relationship: claimant[:relationship],
          claimant_address_line1: address[:address_line1],
          claimant_address_line2: address[:address_line2],
          claimant_city: address[:city],
          claimant_state_code: address[:state_code],
          claimant_country: country_code,
          claimant_zip_code: address[:zip_code],
          claimant_zip_code_suffix: address[:zip_code_suffix],
          claimant_phone: claimant[:phone]&.gsub(/\D/, ''),
          claimant_email: claimant[:email]
        }
      end

      def flatten_veteran_params(veteran_params)
        veteran = veteran_params[:veteran]
        address = veteran[:address]
        country_code = normalize_country_code_to_alpha2(address[:country])
        { veteran_first_name: veteran.dig(:name, :first),
          veteran_middle_initial: veteran.dig(:name, :middle)&.chr,
          veteran_last_name: veteran.dig(:name, :last),
          veteran_social_security_number: veteran[:ssn],
          veteran_va_file_number: veteran[:va_file_number],
          veteran_date_of_birth: veteran[:date_of_birth],
          veteran_service_number: veteran[:service_number],
          veteran_address_line1: address[:address_line1],
          veteran_address_line2: address[:address_line2],
          veteran_city: address[:city],
          veteran_state_code: address[:state_code],
          veteran_country: country_code,
          veteran_zip_code: address[:zip_code],
          veteran_zip_code_suffix: address[:zip_code_suffix],
          veteran_phone: veteran[:phone]&.gsub(/\D/, ''),
          veteran_email: veteran[:email] }
      end

      def name_params_permitted
        %i[first middle last]
      end

      def address_params_permitted
        %i[
          address_line1
          address_line2
          city
          state_code
          country
          zip_code
          zip_code_suffix
        ]
      end

      def normalize_country_code_to_alpha2(country_code)
        if country_code.present?
          IsoCountryCodes.find(country_code).alpha2
        else
          ''
        end
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
