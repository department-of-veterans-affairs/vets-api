# frozen_string_literal: true
require 'unified_health_data/service'
require 'mobile/v1/medical_record_serializer'

module Mobile
  module V1
    class LabsAndTestsController < ApplicationController
      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        medical_records = service.get_medical_records(start_date: start_date, end_date: end_date)
        render json: medical_records.map { |record| MedicalRecordSerializer.serialize(record) }
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
