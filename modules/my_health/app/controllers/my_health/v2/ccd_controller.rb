# frozen_string_literal: true

require 'unified_health_data/service'

module MyHealth
  module V2
    class CcdController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      service_tag 'mhv-medical-records'

      def download
        file_format = params[:format] || 'xml'
        binary_data = service.get_ccd_binary(format: file_format)

        if binary_data.nil?
          render_error('CCD Not Found', 'The requested CCD was not found', '404', 404, :not_found)
          return
        end

        send_data Base64.decode64(binary_data.binary),
                  type: binary_data.content_type,
                  disposition: "attachment; filename=ccd.#{file_format.downcase}",
                  status: :ok
      rescue ArgumentError => e
        render_error('CCD Format Not Found', e.message, '404', 404, :not_found)
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'CCD', api_type: 'FHIR', use_dynamic_status: true, include_backtrace: true)
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
