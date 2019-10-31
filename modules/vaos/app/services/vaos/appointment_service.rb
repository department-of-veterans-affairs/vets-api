# frozen_string_literal: true

module VAOS
  class AppointmentService < Common::Client::Base
    include Common::Client::Monitoring

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_appointments(user, type, start_date, end_date, pagination_params = {})
      with_monitoring do
        url = get_appointments_url(user, type, start_date, end_date, pagination_params)

        response = perform(:get, url, headers(user))
        {
          data: deserialized_appointments(response.body, type),
          meta: pagination(pagination_params)
        }
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

    def get_appointments_url(user, type, start_date, end_date, pagination_params)
      url = if type == 'va'
              "/appointments/v1/patients/#{user.icn}/appointments"\
                  "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false"
            else
              '/VeteranAppointmentRequestService/v4/rest/direct-scheduling/'\
                  "patient/ICN/#{user.icn}/booked-cc-appointments"\
                  "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false"
            end

      if pagination_params[:per_page]&.positive?
        url + "&pageSize=#{pagination_params[:per_page]}&page=#{pagination_params[:page]}"
      else
        url + "&pageSize=#{pagination_params[:per_page] || 0}"
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
