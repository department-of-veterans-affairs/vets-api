# frozen_string_literal: true

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging

module HealthQuest
  class PGDService < HealthQuest::SessionService
    def get_pgd_resource(type, id = nil, pagination_params = {})
      with_monitoring do
        response = perform(:get, get_pgd_base_url(type, id), {}, headers, timeout: 55)
        {
          data: deserialized_resource(response.body, type),
          meta: pagination(pagination_params)
        }
      end
    end

    private

    def deserialized_resource(json_hash, type = nil)
      result = json_hash[:data]
      result[:type] = type if type
      return [] unless result

      result.is_a?(Array) ? result.map { |el| OpenStruct.new(el) } : OpenStruct.new(result)
    end

    def pagination(pagination_params)
      {
        pagination: {
          current_page: pagination_params[:page] || 0,
          per_page: pagination_params[:per_page] || 0,
          total_pages: 0,
          total_entries: 0
        }
      }
    end

    def get_pgd_base_url(type, id = nil)
      base = "/#{type}/v1/patients/#{user.icn}"
      id ? "#{base}/#{id}" : base
    end

    def page_params(pagination_params)
      if pagination_params[:per_page]&.positive?
        { pageSize: pagination_params[:per_page], page: pagination_params[:page] }
      else
        { pageSize: pagination_params[:per_page] || 0 }
      end
    end
  end
end
