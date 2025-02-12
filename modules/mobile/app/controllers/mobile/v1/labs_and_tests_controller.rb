# frozen_string_literal: true
require 'unified_health_data/service'

module Mobile
  module V1
    class LabsAndTestsController < ApplicationController
      def index
        service = UnifiedHealthData::Service.new
        medical_records = service.get_medical_records
        render json: medical_records.map { |record| serialize_record(record) }
      end

      private

      def serialize_record(record)
        {
          id: record.id,
          type: record.type,
          attributes: {
            display: record.attributes.display,
            test_code: record.attributes.test_code,
            date_completed: record.attributes.date_completed,
            sample_site: record.attributes.sample_site,
            encoded_data: record.attributes.encoded_data,
            location: record.attributes.location
          }
        }
      end
    end
  end
end
