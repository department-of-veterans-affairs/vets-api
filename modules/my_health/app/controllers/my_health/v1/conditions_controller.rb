# frozen_string_literal: true

module MyHealth
  module V1
    class ConditionsController < MrController
      def index
        patient_id = params[:patient_id]
        resource = client.list_conditions(patient_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end

      def show
        condition_id = params[:id].try(:to_i)
        resource = client.get_condition(condition_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end
    end
  end
end
