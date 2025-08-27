# frozen_string_literal: true

require 'unified_health_data/service'
require 'condition_serializer'

module MyHealth
  module V2
    class ConditionsController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        conditions = service.get_conditions(start_date:, end_date:)
        render json: conditions.map { |record| ConditionSerializer.serialize(record) }
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
