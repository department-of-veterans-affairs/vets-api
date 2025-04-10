# frozen_string_literal: true

require 'unified_health_data/service'
require 'lab_or_test_serializer'

module MyHealth
  module V2
    class LabsAndTestsController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        labs = service.get_labs(start_date:, end_date:)
        render json: labs.map { |record| LabOrTestSerializer.serialize(record) }
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
