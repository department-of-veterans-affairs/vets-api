# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module Mobile
  module V0
    class LabsAndTestsController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        response = client.list_diagnostic_reports(params)
        diagnostic_reports = response.body['entry'].map do |entry|
          Mobile::V0::Adapters::DiagnosticReport.new.parse(entry['resource'])
        end

        render json: DiagnosticReportsSerializer.new(diagnostic_reports)
      end

      private

      def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn)
      end
    end
  end
end
