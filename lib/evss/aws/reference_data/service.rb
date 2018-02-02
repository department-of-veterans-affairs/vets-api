# frozen_string_literal: true
require 'evss/jwt'

module EVSS
  module AWS
    module ReferenceData
      class Service < EVSS::Service
        include Common::Client::Monitoring

        configuration EVSS::AWS::ReferenceData::Configuration

        def get_countries
          raw_response = nil
          with_monitoring do
            raw_response = perform(:get, 'countries')
            EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
          end
        rescue StandardError => e
          handle_error(e)
        end

        def get_states
          raw_response = nil
          with_monitoring do
            raw_response = perform(:get, 'states')
            EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
          end
        rescue StandardError => e
          handle_error(e)
        end

        private

        # overrides EVSS::Service#headers_for_user
        def headers_for_user(user)
          {
            Authorization: "Bearer #{EVSS::Jwt.new(user).encode}"
          }
        end
      end
    end
  end
end
