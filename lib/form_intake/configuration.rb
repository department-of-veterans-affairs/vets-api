# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module FormIntake
  # HTTP client config for GCIO->IBM structured form data API integration
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.form_intake.timeout || 30
    def base_path
      # I.e.: https://fwdproxy-prod.vfs.va.gov:4440 which is used to reach the API
      # shown here https://staging.digitization.gcio.com/va/upload/api/swagger/index.html#/Form%20Validation%20Service/putValidatedForm
      Settings.form_intake.host
    end

    def service_path
      # I.e.: https://fwdproxy-prod.vfs.va.gov:4440/api/validated-forms/v1
      "#{base_path}/#{Settings.form_intake.path}/#{Settings.form_intake.api_version}"
    end

    def service_name
      'FormIntake'
    end

    def connection
      @conn ||= Faraday.new(service_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError
        faraday.request :json
        faraday.response :betamocks if use_mocks?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    def use_mocks?
      Settings.form_intake.use_mocks || false
    end

    def breakers_error_threshold
      Settings.form_intake.breakers_error_threshold || 80
    end
  end
end
