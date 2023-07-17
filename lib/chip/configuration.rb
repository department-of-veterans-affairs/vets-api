# frozen_string_literal: true

module Chip
  class Configuration < Common::Client::Configuration::REST
    def server_url
      "#{Settings.chip.url}/#{Settings.chip.base_path}"
    end

    def api_user
      Settings.chip.tmp_api_user
    end

    def api_id
      Settings.chip.tmp_api_id
    end

    def api_username
      Settings.chip.tmp_api_username
    end

    def service_name
      'Chip'
    end

    def connection
      Faraday.new(url: server_url) do |conn|
        conn.use :breakers
        conn.response :raise_error, error_prefix: service_name
        conn.response :betamocks if Settings.chip.mock?

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
