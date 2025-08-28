# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/condition_serializer'

module MyHealth
  module V2
    class ConditionsController < ApplicationController
      service_tag 'mhv-medical-records'
      # skip_before_action :authenticate # TODO: Uncomment for local testing

      def index
        conditions = service.get_conditions
        render json: UnifiedHealthData::Serializers::ConditionSerializer.new(conditions).serializable_hash[:data]
      end

      private

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
