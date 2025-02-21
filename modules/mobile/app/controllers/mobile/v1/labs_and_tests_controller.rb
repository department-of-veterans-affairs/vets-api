# frozen_string_literal: true
require 'unified_health_data/service'

module Mobile
  module V1
    class LabsAndTestsController < ApplicationController
      def index
        medical_records = service.get_medical_records
        render json: medical_records.map { |record| serialize_record(record) }
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end

      # TODO separate serializer?
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
            location: record.attributes.location,
            ordered_by: record.attributes.ordered_by,
            observations: record.attributes.observations.map do |obs|
              {
                test_code: obs.test_code,
                sample_site: obs.sample_site,
                encoded_data: obs.encoded_data,
                value_quantity: obs.value_quantity,
                reference_range: obs.reference_range,
                status: obs.status,
                comments: obs.comments
              }
            end
          }
        }
      end
    end
  end
end
