# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class VeteranProfile < ProfileBuilderBase
        class VeteranProfileError < StandardError; end

        def call
          if inquiry_details[:inquiry_about] == 'A general question'
            base_profile
          elsif i_am_the_veteran?
            base_profile
              .merge(contact_info)
              .merge(school_info)
              .merge(service_info(veteran_info))
          else
            base_profile
              .merge(service_info(veteran_info))
          end
        end

        private

        def service_info(info)
          {
            BranchOfService: info[:branch_of_service],
            SSN: info.dig(:social_or_service_num, :ssn) || info[:social_num],
            EDIPI: i_am_the_veteran? ? user&.edipi : nil,
            ICN: i_am_the_veteran? ? user&.icn : nil,
            ServiceNumber: info.dig(:social_or_service_num, :service_number)
          }
        end

        # Builds the base profile payload
        def base_profile
          {
            FirstName: veteran_info[:first],
            MiddleName: veteran_info[:middle],
            LastName: veteran_info[:last],
            PreferredName: preferred_name,
            Suffix: @translator.call(:suffix, veteran_info[:suffix]),
            Country: country_data_or_default,
            **address_data(veteran_address, postal_code, inquiry_params[:veterans_location_of_residence]),
            DateOfBirth: veteran_info[:date_of_birth]
          }
        end

        # Determines if the inquiry is about the veteran
        def i_am_the_veteran?
          inquiry_params[:relationship_to_veteran] == "I'm the Veteran"
        end

        # Returns veteran info based on inquiry context
        def veteran_info
          i_am_the_veteran? ? inquiry_params[:about_yourself] : inquiry_params[:about_the_veteran] || {}
        end

        # Returns the veteran's address based on inquiry context
        def veteran_address
          i_am_the_veteran? ? (inquiry_params[:address] || {}) : {}
        end

        # Returns the postal code based on inquiry context
        def postal_code
          i_am_the_veteran? ? inquiry_params[:your_postal_code] : inquiry_params[:veterans_postal_code]
        end

        # Returns the preferred name based on inquiry context
        def preferred_name
          i_am_the_veteran? ? inquiry_params[:preferred_name] : veteran_info[:preferred_name]
        end

        # Returns country data or default values
        def country_data_or_default
          i_am_the_veteran? ? country_data(inquiry_params[:country]) : { Name: nil, CountryCode: nil }
        end
      end
    end
  end
end
