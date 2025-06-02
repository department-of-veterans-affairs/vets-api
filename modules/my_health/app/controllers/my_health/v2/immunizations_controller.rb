# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'lighthouse/veterans_health/models/immunization'
require 'lighthouse/veterans_health/serializers/immunization_serializer'

module MyHealth
  module V2
    class ImmunizationsController < ApplicationController
      service_tag 'mhv-medical-records'

      STATSD_KEY_PREFIX = 'api.my_health.immunizations'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        response = client.get_immunizations(start_date:, end_date:)
        immunizations = Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer.from_fhir_bundle(response.body)
        
        # Track the number of immunizations returned to the client
        StatsD.gauge("#{STATSD_KEY_PREFIX}.count", immunizations.length)
        
        render json: { data: immunizations }
      end

      private

       def client
        @client ||= Lighthouse::VeteransHealth::Client.new('1013956965V299908') # Example ICN, replace with actual user ICN
      end
    end
  end
end