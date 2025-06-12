# frozen_string_literal: true

module MyHealth
  module V1
    class LabsAndTestsController < MRController
      def index
        render_resource client.list_labs_and_tests
      end

      def show
        record_id = params[:id].try(:to_i)
        render_resource client.get_diagnostic_report(record_id)
      end
    end
  end
end
