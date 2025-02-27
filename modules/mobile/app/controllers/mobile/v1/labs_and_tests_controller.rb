# frozen_string_literal: true

require 'unified_health_data/service'
require 'mobile/v1/lab_or_test_serializer'

module Mobile
  module V1
    class LabsAndTestsController < ApplicationController
      before_action :controller_enabled?

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        medical_records = service.get_medical_records(start_date:, end_date:)
        render json: medical_records.map { |record| LabOrTestSerializer.serialize(record) }
      end

      private

      def controller_enabled?
        routing_error unless Flipper.enabled?(:mhv_accelerated_delivery_uhd_enabled, @current_user)
      end

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
