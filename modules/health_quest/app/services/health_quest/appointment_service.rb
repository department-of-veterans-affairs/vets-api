# frozen_string_literal: true

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging

module HealthQuest
  class AppointmentService < HealthQuest::SessionService
    def get_appointments(start_date, end_date, pagination_params = {})
      params = date_params(start_date, end_date).merge(page_params(pagination_params)).merge(other_params).compact

      with_monitoring do
        response = perform(:get, get_appointments_base_url, params, headers, timeout: 55)
        {
          data: deserialized_appointments(response.body),
          meta: pagination(pagination_params)
        }
      end
    end

    def get_appointment_by_id(id)
      with_monitoring do
        response = perform(:get, "#{get_appointments_base_url}/#{id}", {}, headers, timeout: 55)
        {
          data: OpenStruct.new(response.body),
          meta: pagination({})
        }
      end
    end

    private

    def deserialized_appointments(json_hash)
      appointment_list = json_hash.dig(:data, :appointment_list)
      return [] unless appointment_list

      appointment_list.map { |appointments| OpenStruct.new(appointments) }
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

    def get_appointments_base_url
      "/appointments/v1/patients/#{user.icn}/appointments"
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
