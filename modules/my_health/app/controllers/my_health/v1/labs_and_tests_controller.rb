# frozen_string_literal: true

module MyHealth
  module V1
    class LabsAndTestsController < MrController
      def index
        resource = client.list_labs_and_tests
        render json: resource.to_json
      end

      def show
        record_id = params[:id].try(:to_i)
        resource = client.get_diagnostic_report(record_id)
        render json: resource.to_json
      end
    end
  end
end
