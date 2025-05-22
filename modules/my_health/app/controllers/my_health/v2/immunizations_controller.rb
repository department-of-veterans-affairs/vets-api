# frozen_string_literal: true

require 'unified_health_data/service'
# require 'immunization_serializer'

module MyHealth
  module V2
    class ImmunizationsController < ApplicationController
      service_tag 'mhv-medical-records'
      skip_before_action :authenticate, only: [:index]

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        # immunizations = service.get_immunizations(start_date:, end_date:)
        # render json: immunizations.map { |record| ImmunizationSerializer.serialize(record) }
        render json: { data: [], meta:  {params: { start_date:, end_date: } } }
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end