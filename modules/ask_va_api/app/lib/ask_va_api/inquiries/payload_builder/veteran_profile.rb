# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class VeteranProfile
        include SharedHelpers

        class VeteranProfileError < StandardError; end

        attr_reader :inquiry_params, :inquiry_details

        def initialize(inquiry_params:, inquiry_details:)
          @inquiry_params = inquiry_params
          @inquiry_details = inquiry_details
          @translator = Translator.new
        end

        def call
          base_profile
            .merge(service_info)
        end

        private

        def veteran_info
          inquiry_params[:about_the_veteran]
        end

        def base_profile
          {
            FirstName: veteran_info[:first],
            MiddleName: veteran_info[:middle],
            LastName: veteran_info[:last],
            PreferredName: veteran_info[:preferred_name],
            Suffix: @translator.call(:suffix, veteran_info[:suffix]),
            Country: nil,
            Street: veteran_info[:street],
            City: veteran_info[:city],
            State: state_data,
            ZipCode: inquiry_params[:veteran_postal_code],
            DateOfBirth: veteran_info[:date_of_birth]
          }
        end

        def service_info
          {
            BranchOfService: veteran_info[:branch_of_service],
            SSN: veteran_info.dig(:social_or_service_num, :ssn),
            ServiceNumber: veteran_info.dig(:social_or_service_num, :service_number),
            ClaimNumber: nil,
            VeteranServiceStateDate: nil,
            VeteranServiceEndDate: nil
          }
        end

        def state_data
          {
            Name: inquiry_params[:veterans_location_of_residence],
            StateCode: fetch_state_code(inquiry_params[:veterans_location_of_residence])
          }
        end
      end
    end
  end
end
