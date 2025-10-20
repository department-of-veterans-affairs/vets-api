# frozen_string_literal: true

require 'unified_health_data/service'

module MyHealth
  module V2
    class CcdController < ApplicationController
      service_tag 'mhv-medical-records'

      def download
        file_format = params[:file_format] || 'xml'
        binary_data = fetch_ccd_binary(file_format)
        return if binary_data.nil?

        send_ccd_file(binary_data, file_format)
      rescue ArgumentError => e
        render_error('Invalid Format', e.message, '400', 400, :bad_request)
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e)
      end

      private

      def fetch_ccd_binary(file_format)
        unless params[:start_date].present? && params[:end_date].present?
          render_error('Missing Parameters',
                       'start_date and end_date are required parameters',
                       '400', 400, :bad_request)
          return nil
        end

        binary_data = service.get_ccd_binary(
          start_date: params[:start_date],
          end_date: params[:end_date],
          format: file_format
        )

        if binary_data.nil?
          render_error('CCD Not Found',
                       'The requested CCD was not found',
                       '404', 404, :not_found)
          return nil
        end

        binary_data
      end

      def send_ccd_file(binary_data, file_format)
        decoded_data = Base64.decode64(binary_data.binary)

        send_data decoded_data,
                  type: binary_data.content_type,
                  disposition: "attachment; filename=\"ccd.#{extension_for_format(file_format)}\"",
                  status: :ok
      end

      def handle_error(error)
        log_error(error)

        case error
        when Common::Client::Errors::ClientError
          status_symbol = Rack::Utils::SYMBOL_TO_STATUS_CODE.key(error.status) || :bad_gateway
          render_error('FHIR API Error', error.message, error.status, error.status, status_symbol)
        when Common::Exceptions::BackendServiceException
          render json: { errors: error.errors }, status: :bad_gateway
        else
          render_error('Internal Server Error',
                       'An unexpected error occurred while retrieving CCD.',
                       '500', 500, :internal_server_error)
        end
      end

      def log_error(error)
        message = case error
                  when Common::Client::Errors::ClientError
                    "CCD FHIR API error: #{error.message}"
                  when Common::Exceptions::BackendServiceException
                    "Backend service exception: #{error.errors.first&.detail}"
                  else
                    "Unexpected error in CCD controller: #{error.message}"
                  end
        Rails.logger.error(message)
        Rails.logger.error("Backtrace: #{error.backtrace.first(10).join("\n")}")
      end

      def render_error(title, detail, code, status, http_status)
        error = {
          title:,
          detail:,
          code:,
          status:
        }
        render json: { errors: [error] }, status: http_status
      end

      def extension_for_format(file_format)
        case file_format.downcase
        when 'html' then 'html'
        when 'pdf' then 'pdf'
        else 'xml'
        end
      end

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
