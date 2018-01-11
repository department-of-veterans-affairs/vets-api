# frozen_string_literal: true
require 'evss/jwt'

module EVSS
  module ReferenceData
    class Service < EVSS::Service
      configuration EVSS::ReferenceData::Configuration

      def get_countries
        raw_response = nil
        with_monitoring do
          raw_response = perform(:get, 'countries')
        end
        raw_response&.body&.dig('countries') || []
      end

      def get_disabilities
        raw_response = perform(:get, 'disabilities')
      end

      def get_intake_sites
        raw_response = perform(:get, 'intakesites')
      end

      def get_states
        raw_response = perform(:get, 'states')
      end

      def get_treatment_centers
        # TODO: recommend this be a GET not POST
        raw_response = perform(:post, 'treatmentcenters')
      end

      private

      # overrides EVSS::Service#headers_for_user
      def headers_for_user(user)
        {
          Authorization: "Bearer #{EVSS::Jwt.new(user).encode}"
        }.to_h
      end
    end
  end
end
