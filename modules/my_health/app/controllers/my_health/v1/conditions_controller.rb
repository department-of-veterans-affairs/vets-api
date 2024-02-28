# frozen_string_literal: true

module MyHealth
  module V1
    class ConditionsController < MrController
      def index
        resource = client.list_conditions
        render json: resource.to_json
      rescue ::MedicalRecords::PatientNotFound
        render body: nil, status: :accepted
      end

      def show
        condition_id = params[:id].try(:to_i)
        resource = client.get_condition(condition_id)
        render json: resource.to_json
      rescue ::MedicalRecords::PatientNotFound
        render body: nil, status: :accepted
      end
    end
  end
end
