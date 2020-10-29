# frozen_string_literal: true

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging

module HealthQuest
  class AppointmentService < HealthQuest::SessionService
    def get_appointment_by_id(_id)
      with_monitoring do
        response =
          YAML.load_file(Rails.root.join(*appt_file)).with_indifferent_access

        {
          data: OpenStruct.new(response[:body][:data]),
          meta: pagination({})
        }
      end
    end

    private

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

    def appt_file
      ['modules', 'health_quest', 'app', 'services', 'health_quest', 'mock_responses', 'appointment.yml']
    end
  end
end
