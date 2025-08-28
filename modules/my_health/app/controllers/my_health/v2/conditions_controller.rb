# frozen_string_literal: true

require 'unified_health_data/service'
require 'condition_serializer'

module MyHealth
  module V2
    class ConditionsController < ApplicationController
      service_tag 'mhv-medical-records'
      # skip_before_action :authenticate # TODO: Uncomment for local testing

      def index
        conditions = service.get_conditions
        render json: conditions.map { |record| ConditionSerializer.serialize(record) }
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
