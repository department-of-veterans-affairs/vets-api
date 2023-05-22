# frozen_string_literal: true

module MyHealth
  module V1
    class LabsAndTestsController < MrController
      def index
        patient_id = params[:patient_id]
        resource = client.list_labs_and_tests(patient_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end

      def show
        record_id = params[:id].try(:to_i)
        resource = client.get_diagnostic_report(record_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end
    end
  end
end
