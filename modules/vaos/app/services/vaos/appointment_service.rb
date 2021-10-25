# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  class AppointmentService < VAOS::SessionService
    def get_appointments(type, start_date, end_date, pagination_params = {})
      params = date_params(start_date, end_date).merge(page_params(pagination_params)).merge(other_params).compact

      with_monitoring do
        response = perform(:get, get_appointments_base_url(type), params, headers, timeout: 55)

        {
          data: deserialized_appointments(response.body, type),
          meta: pagination(pagination_params).merge(partial_errors(response))
        }
      end
    end

    def get_appointment(id)
      params = {}

      with_monitoring do
        response = perform(:get, show_appointment_url(id), params, headers)
        # handle VAMF http status 204 and an empty string is returned in the body, issue va.gov-team/28630
        response.body.blank? ? OpenStruct.new(nil) : OpenStruct.new(response.body)
      end
    end

    def post_appointment(request_object_body)
      params = VAOS::AppointmentForm.new(user, request_object_body).params.with_indifferent_access
      site_code = params[:clinic][:site_code]

      with_monitoring do
        response = perform(:post, post_appointment_url(site_code), params, headers)
        {
          data: OpenStruct.new(response.body),
          meta: {}
        }
      rescue Common::Exceptions::BackendServiceException => e
        log_direct_schedule_submission_errors(e)
        # TODO: Reevaluate the need to log clinic data three months after launch (6/15/20)
        log_clinic_details(:create, params.dig(:clinic, :clinic_id), site_code) if e.key == 'VAOS_400'
        raise e
      end
    end

    def put_cancel_appointment(request_object_body)
      params = VAOS::CancelForm.new(request_object_body).params
      params.merge!(patient_identifier: { unique_id: user.icn, assigning_authority: 'ICN' })
      site_code = params[:facility_id]

      with_monitoring do
        perform(:put, put_appointment_url(site_code), params, headers)
        ''
      rescue Common::Exceptions::BackendServiceException => e
        # TODO: Reevaluate the need to log clinic data three months after launch (6/15/20)
        log_clinic_details(:cancel, params[:clinic_id], site_code) if e.key == 'VAOS_409A' || e.key == 'VAOS_400'
        raise e
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def log_direct_schedule_submission_errors(e)
      Rails.logger.warn('Direct schedule submission error', { status: e.status_code, message: e.message })
    end

    def log_clinic_details(action, clinic_id, site_code)
      Rails.logger.warn(
        "Clinic does not support VAOS appointment #{action}",
        clinic_id: clinic_id,
        site_code: site_code
      )
    end

    def deserialized_appointments(json_hash, type)
      appointment_list = if type == 'va'
                           json_hash.dig(:data, :appointment_list)
                         else
                           json_hash[:booked_appointment_collections].first[:booked_cc_appointments]
                         end
      return [] unless appointment_list

      appointment_list.map { |appointment| OpenStruct.new(appointment) }
    end

    # TODO: need underlying APIs to support pagination consistently
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
      if response.status == 200 && response.body[:errors]&.any?
        log_message_to_sentry(
          'VAOS::AppointmentService#get_appointments has response errors.',
          :info,
          errors: response.body[:errors].to_json
        )
      end

      {
        errors: (response.body[:errors] || []) # VAMF drops null valued keys; ensure we always return empty array
      }
    end

    def get_appointments_base_url(type)
      if type == 'va'
        "/appointments/v1/patients/#{user.icn}/appointments"
      else
        "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/patient/ICN/#{user.icn}/booked-cc-appointments"
      end
    end

    def show_appointment_url(id)
      "/appointments/v1/patients/#{user.icn}/appointments/#{id}"
    end

    def post_appointment_url(site)
      "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{site}" \
        "/patient/ICN/#{user.icn}/booked-appointments"
    end

    def put_appointment_url(site)
      "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{site}/patient/ICN/" \
        "#{user.icn}/cancel-appointment"
    end

    def date_params(start_date, end_date)
      { startDate: date_format(start_date), endDate: date_format(end_date) }
    end

    def page_params(pagination_params)
      if pagination_params[:per_page]&.positive?
        { pageSize: pagination_params[:per_page], page: pagination_params[:page] }
      else
        { pageSize: pagination_params[:per_page] || 0 }
      end
    end

    def other_params(use_cache = false)
      { useCache: use_cache }
    end

    def date_format(date)
      date.strftime('%Y-%m-%dT%TZ')
    end
  end
end
