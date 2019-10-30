# frozen_string_literal: true

module VAOS
  class AppointmentService < Common::Client::Base
    include Common::Client::Monitoring

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_va_appointments(user, start_date, end_date, pagination_params = {})
      with_monitoring do
        url = get_va_appointments_url(user.icn, start_date, end_date, pagination_params)

        response = perform(:get, url, headers(user))
        {
          data: deserialized_va_appointments(response.body),
          meta: pagination(pagination_params)
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    def get_cc_appointments(user, start_date, end_date, pagination_params = {})
      with_monitoring do
        url = get_cc_appointments_url(user.icn, start_date, end_date, pagination_params)
        response = perform(:get, url, headers(user))
        {
          data: deserialized_cc_appointments(response.body),
          meta: pagination(pagination_params)
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def deserialized_va_appointments(json_hash)
      json_hash.dig(:data, :appointment_list).map { |appointments| OpenStruct.new(appointments) }
    end

    def deserialized_cc_appointments(json_hash)
      json_hash[:booked_appointment_collections].first[:booked_cc_appointments]
                                                .map { |appointments| OpenStruct.new(appointments) }
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

    def get_va_appointments_url(icn, start_date, end_date, pagination_params)
      "/appointments/v1/patients/#{icn}/appointments"\
          "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false" +
        pagination_partial_url(pagination_params)
    end

    def get_cc_appointments_url(icn, start_date, end_date, pagination_params)
      '/VeteranAppointmentRequestService/v4/rest/direct-scheduling/'\
          "patient/ICN/#{icn}/booked-cc-appointments"\
          "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false" +
        pagination_partial_url(pagination_params)
    end

    def pagination_partial_url(pagination_params)
      if pagination_params[:per_page]&.positive?
        "&pageSize=#{pagination_params[:per_page]}&page=#{pagination_params[:page]}"
      else
        "&pageSize=#{pagination_params[:per_page] || 0}"
      end
    end

    def date_format(date)
      date.strftime('%Y-%m-%dT%TZ')
    end

    def headers(user)
      { 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => VAOS::JWT.new(user).token }
    end
  end
end
