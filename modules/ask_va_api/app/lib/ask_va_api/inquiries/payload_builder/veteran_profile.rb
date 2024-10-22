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

        def base_profile
          {
            FirstName: inquiry_params.dig(:about_the_veteran, :first),
            MiddleName: inquiry_params.dig(:about_the_veteran, :middle),
            LastName: inquiry_params.dig(:about_the_veteran, :last),
            PreferredName: inquiry_params.dig(:about_the_veteran, :preferred_name),
            Suffix: @translator.call(inquiry_params.dig(:about_the_veteran, :suffix)),
            Country: nil,
            Street: inquiry_params.dig(:about_the_veteran, :street),
            City: inquiry_params.dig(:about_the_veteran, :city),
            State: state_data,
            ZipCode: inquiry_params[:veteran_postal_code],
            DateOfBirth: inquiry_params.dig(:about_the_veteran, :date_of_birth)
          }
        end

        def service_info
          {
            BranchOfService: inquiry_params.dig(:about_the_veteran, :branch_of_service),
            SSN: inquiry_params.dig(:about_the_veteran, :social_or_service_num, :ssn),
            ServiceNumber: inquiry_params.dig(:about_the_veteran, :social_or_service_num, :service_number),
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
