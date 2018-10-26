# frozen_string_literal: true

module Okta
  class Configuration < Common::Client::Configuration::REST
    def base_path
      'https://deptva-eval-admin.okta.com/api/v1/'
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use :breakers
        faraday.request :url_encoded
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
