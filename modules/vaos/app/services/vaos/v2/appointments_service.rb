# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class AppointmentsService < VAOS::SessionService
      DIRECT_SCHEDULE_ERROR_KEY = 'DirectScheduleError'
      VAOS_SERVICE_DATA_KEY = 'VAOSServiceTypesAndCategory'
      VAOS_TELEHEALTH_DATA_KEY = 'VAOSTelehealthData'

      def get_appointments(start_date, end_date, statuses = nil, pagination_params = {})
        params = date_params(start_date, end_date)
                 .merge(page_params(pagination_params))
                 .merge(status_params(statuses))
                 .compact

        with_monitoring do
          response = perform(:get, appointments_base_url, params, headers)
          response.body[:data].each do |appt|
            find_and_log_service_type_and_category(appt)
            log_telehealth_data(appt[:telehealth]&.[](:atlas)) unless appt[:telehealth]&.[](:atlas).nil?
          end
          {
            data: deserialized_appointments(response.body[:data]),
            meta: pagination(pagination_params).merge(partial_errors(response))
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
          find_and_log_service_type_and_category(response.body)
          log_telehealth_data(response.body[:telehealth]&.[](:atlas)) unless response.body[:telehealth]&.[](:atlas).nil?
          OpenStruct.new(response.body)
        rescue Common::Exceptions::BackendServiceException => e
          log_direct_schedule_submission_errors(e) if params[:status] == 'booked'
          raise e
        end
      end

      def update_appointment(appt_id, status)
        url_path = "/vaos/v1/patients/#{user.icn}/appointments/#{appt_id}"
        params = VAOS::V2::UpdateAppointmentForm.new(status:).params
        with_monitoring do
          response = perform(:put, url_path, params, headers)
          OpenStruct.new(response.body)
        end
      end

      private

      def log_direct_schedule_submission_errors(e)
        error_entry = { DIRECT_SCHEDULE_ERROR_KEY => ds_error_details(e) }
        Rails.logger.warn('Direct schedule submission error', error_entry.to_json)
      end

      def ds_error_details(e)
        {
          status: e.status_code,
          message: e.message
        }
      end

      def log_telehealth_data(atlas_data)
        atlas_entry = { VAOS_TELEHEALTH_DATA_KEY => atlas_details(atlas_data) }
        Rails.logger.info('VAOS telehealth atlas details', atlas_entry.to_json)
      end

      def atlas_details(atlas_data)
        {
          siteCode: atlas_data&.[](:site_code),
          address: atlas_data&.[](:address)
        }
      end

      def find_and_log_service_type_and_category(appt)
        service_category_found = process_service_types_or_category(appt[:service_category])
        service_types_array_found = process_service_types_or_category(appt[:service_types])
        service_type_found = appt[:service_type]
        log_service_type_and_category(type_and_category_data(service_type_found, service_types_array_found,
                                                             service_category_found))
      end

      def process_service_types_or_category(appt_service_data)
        found_values = []
        appt_service_data&.each do |type_or_category_el|
          type_or_category_el&.[](:coding)&.each do |coding_el|
            service_type_or_category_data = coding_el&.[](:code)
            found_values << service_type_or_category_data
          end
        end
        found_values
      end

      def type_and_category_data(type, types_array, category)
        {
          vaos_service_type: type,
          vaos_service_types_array: types_array,
          vaos_service_category: category
        }
      end

      def log_service_type_and_category(service_data)
        service_log_entry = { VAOS_SERVICE_DATA_KEY => service_data }
        Rails.logger.info('VAOS appointment service category and type', service_log_entry.to_json)
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

      def partial_errors(response)
        if response.status == 200 && response.body[:failures]&.any?
          log_message_to_sentry(
            'VAOS::V2::AppointmentService#get_appointments has response errors.',
            :info,
            failures: response.body[:failures].to_json
          )
        end

        {
          failures: (response.body[:failures] || []) # VAMF drops null valued keys; ensure we always return empty array
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
        { statuses: }
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
