# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class AppointmentService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    attr_accessor :user

    def self.for_user(user)
      as = VAOS::AppointmentService.new
      as.user = user
      as
    end

    def self.test
      user = FactoryBot.build(:user, :vaos)
      service = for_user(user)
      params = {
        scheduling_request_type: 'NEXT_AVAILABLE_APPT',
        type: 'REGULAR',
        appointment_kind: 'TRADITIONAL',
        scheduling_method: 'direct',
        appt_type: 'P',
        purpose: '9',
        lvl: '1',
        ekg: '',
        lab: '',
        x_ray: '',
        preferred_email: 'abraham.lincoln@va.gov',
        time_zone: 'America/Denver',
        desired_date: 5.days.from_now.utc.change(hour: 0).iso8601(3),
        date_time: 5.days.from_now.utc.iso8601(3),
        duration: 30,
        booking_notes: 'Follow-up/Routine: abdominal pain',
        clinic: {
          site_code: '983',
          clinic_id: '308',
          clinic_name: 'CHY PC KILPATRICK',
          clinic_friendly_location_name: 'Green Team Clinic1',
          institution_name: 'CHYSHR-Cheyenne VA Medical Center',
          institution_code: '983'
        }
      }

      response = service.post_appointment(params)
    end

    def get_appointments(type, start_date, end_date, pagination_params = {})
      params = date_params(start_date, end_date).merge(page_params(pagination_params)).merge(other_params).compact

      with_monitoring do
        response = perform(:get, get_appointments_base_url(type), params, headers(user))
        {
          data: deserialized_appointments(response.body, type),
          meta: pagination(pagination_params)
        }
      end
    end

    def post_appointment(request_object_body)
      params = VAOS::AppointmentForm.new(user, request_object_body).params
      site_codes = params.dig(:patients, :patient).map { |patient| patient.dig(:location, :facility, :site_code) }

      # if site_codes ever has more than one value, we might want to log it and investigate or something... Why is
      # patient an array in the payload? you're going to go see the doctor as a group?
      with_monitoring do
        binding.pry
        response = perform(:post, post_appointment_url(site_codes.first), params, headers(user))
        {
          data: OpenStruct.new(response.body),
          meta: {}
        }
      end
    end

    def put_cancel_appointment(request_object_body)
      params = VAOS::CancelForm.new(request_object_body).params
      params.merge!(patient_identifier: { unique_id: user.icn, assigning_authority: 'ICN' })

      with_monitoring do
        perform(:put, put_appointment_url, params, headers(user))
        ''
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def deserialized_appointments(json_hash, type)
      if type == 'va'
        json_hash.dig(:data, :appointment_list).map { |appointments| OpenStruct.new(appointments) }
      else
        json_hash[:booked_appointment_collections].first[:booked_cc_appointments]
                                                  .map { |appointments| OpenStruct.new(appointments) }
      end
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash, appointments_type: type)
      []
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

    def get_appointments_base_url(type)
      if type == 'va'
        "/appointments/v1/patients/#{user.icn}/appointments"
      else
        "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/patient/ICN/#{user.icn}/booked-cc-appointments"
      end
    end

    def post_appointment_url(site)
      "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{site}" +
        "/patient/ICN/#{user.icn}/booked-appointments"
    end

    def put_appointment_url
      '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/983/patient/ICN/' \
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
