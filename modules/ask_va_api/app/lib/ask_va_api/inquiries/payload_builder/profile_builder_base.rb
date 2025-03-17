# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class ProfileBuilderBase
        include SharedHelpers

        attr_reader :inquiry_params, :user, :inquiry_details

        def initialize(inquiry_params:, user:, inquiry_details:)
          @inquiry_params = inquiry_params
          @user = user
          @inquiry_details = inquiry_details
          @translator = Translator.new
        end

        private

        def country_data(country_code)
          {
            Name: fetch_country(country_code),
            CountryCode: country_code
          }
        end

        def state_data(state, location_of_residence = nil)
          {
            Name: fetch_state(state) || location_of_residence,
            StateCode: state || fetch_state_code(location_of_residence)
          }
        end

        def address_data(address, postal_code = nil, location_of_residence = nil)
          {
            Street: address[:street],
            City: address[:city],
            State: state_data(address[:state], location_of_residence),
            ZipCode: address[:postal_code] || postal_code
          }
        end
      end
    end
  end
end
