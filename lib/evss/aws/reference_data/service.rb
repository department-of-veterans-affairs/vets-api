# frozen_string_literal: true
require 'evss/jwt'

module EVSS
  module AWS
    module ReferenceData
      class Service < EVSS::Service
        configuration EVSS::AWS::ReferenceData::Configuration

        def get_countries
          raw_response = nil
          with_monitoring do
            raw_response = perform(:get, 'countries')
          end
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end

        def get_disabilities
          raw_response = nil
          with_monitoring do
            raw_response = perform(:get, 'disabilities')
          end
          EVSS::ReferenceData::DisabilitiesResponse.new(raw_response.status, raw_response)
        end

        def get_intake_sites
          raw_response = nil
          with_monitoring do
            raw_response = perform(:get, 'intakesites')
          end
          EVSS::ReferenceData::IntakeSitesResponse.new(raw_response.status, raw_response)
        end

        def get_states
          raw_response = nil
          #with_monitoring do
            raw_response = perform(:get, 'states')
          #end
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end

        def get_treatment_centers(state)
          raw_response = nil
          with_monitoring do
            raw_response = perform(:get, "treatmentcenters/#{state}")
          end
          EVSS::ReferenceData::TreatmentCentersResponse.new(raw_response.status, raw_response)
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
