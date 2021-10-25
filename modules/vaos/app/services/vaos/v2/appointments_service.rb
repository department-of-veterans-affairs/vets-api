# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class AppointmentsService < VAOS::SessionService
      def get_appointments(start_date, end_date, statuses = nil, pagination_params = {})
        params = date_params(start_date, end_date)
                 .merge(page_params(pagination_params))
                 .merge(status_params(statuses))
                 .compact

        with_monitoring do
          response = perform(:get, appointments_base_url, params, headers)
          {
            data: deserialized_appointments(response.body[:data]),
            meta: pagination(pagination_params)
          }
        end
      end

      def get_appointment(appointment_id)
        params = {}
        with_monitoring do
          response = perform(:get, get_appointment_base_url(appointment_id), params, headers)
          OpenStruct.new(response.body[:data])
        end
      end

      def post_appointment(request_object_body)
        params = VAOS::V2::AppointmentForm.new(user, request_object_body).params.with_indifferent_access
        params.compact_blank!
        with_monitoring do
          response = perform(:post, appointments_base_url, params, headers)
          OpenStruct.new(response.body)
        rescue Common::Exceptions::BackendServiceException => e
          log_direct_schedule_submission_errors(e) if params[:status] == 'booked'
          raise e
        end
      end

      def update_appointment(appt_id, status)
        url_path = "/vaos/v1/patients/#{user.icn}/appointments/#{appt_id}"
        params = VAOS::V2::UpdateAppointmentForm.new(status: status).params
        with_monitoring do
          response = perform(:put, url_path, params, headers)
          OpenStruct.new(response.body)
        end
      end

      private

      def log_direct_schedule_submission_errors(e)
        Rails.logger.warn('Direct schedule submission error', { status: e.status_code, message: e.message })
      end

      def deserialized_appointments(appointment_list)
        return [] unless appointment_list

        appointment_list.map { |appointment| OpenStruct.new(appointment) }
      end

      def pagination(pagination_params)
        {
          pagination: {
            current_page: pagination_params[:page] || 0,
            per_page: pagination_params[:per_page] || 0,
            total_pages: 0, # underlying api doesn't provide this; how do you build a pagination UI without it?
            total_entries: 0 # underlying api doesn't provide this.
          }
        }
      end

      def appointments_base_url
        "/vaos/v1/patients/#{user.icn}/appointments"
      end

      def get_appointment_base_url(appointment_id)
        "/vaos/v1/patients/#{user.icn}/appointments/#{appointment_id}"
      end

      def date_params(start_date, end_date)
        { start: date_format(start_date), end: date_format(end_date) }
      end

      def status_params(statuses)
        { statuses: statuses }
      end

      def page_params(pagination_params)
        if pagination_params[:per_page]&.positive?
          { pageSize: pagination_params[:per_page], page: pagination_params[:page] }
        else
          { pageSize: pagination_params[:per_page] || 0 }
        end
      end

      def date_format(date)
        date.strftime('%Y-%m-%dT%TZ')
      end
    end
  end
end
