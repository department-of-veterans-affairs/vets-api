# frozen_string_literal: true
require 'soap/middleware/request/headers'
require 'soap/middleware/response/parse'

module HealthCareApplications
  class Service
    HEALTH_CHECK_ID = 377_609_264

    def submit_application(form)
      # TODO(molson): Apply HCA transform on form
      submission = soap.build_request(:save_submit_form, form)
      post(submission)
    end

    def health_check
      submission = soap.build_request(:get_form_submission_status, message: { formSubmissionId: HEALTH_CHECK_ID })
      post(submission)
    end

    def self.options
      opts = {
        url: HEALTH_CARE_APPLICATION_CONFIG[:endpoint],
        ssl: {
          verify: true,
          cert_store: HEALTH_CARE_APPLICATION_CONFIG[:cert_store]
        }
      }
      if HEALTH_CARE_APPLICATION_CONFIG[:cert_path] && HEALTH_CARE_APPLICATION_CONFIG[:key_path]
        opts[:ssl].merge(client_cert: HEALTH_CARE_APPLICATION_CONFIG[:cert_path],
                         client_key: HEALTH_CARE_APPLICATION_CONFIG[:key_path])
      end
      opts
    end

    private

    def post(submission)
      connection.post '', submission.body
    end

    def soap
      # Savon *seems* like it should be setting these things correctly
      # from what the docs say. Our WSDL file is weird, maybe?
      Savon.client(wsdl: HEALTH_CARE_APPLICATION_CONFIG[:wsdl],
                   env_namespace: :soap,
                   element_form_default: :qualified,
                   namespaces: {
                     'xmlns:tns': 'http://va.gov/service/esr/voa/v1'
                   },
                   namespace: 'http://va.gov/schema/esr/voa/v1')
    end

    def connection
      @conn ||= Faraday.new(HealthCareApplications::Service.options) do |conn|
        conn.options.open_timeout = 10  # TODO(molson): Make a config/setting
        conn.options.timeout = 15       # TODO(molson): Make a config/setting
        conn.use SOAP::Middleware::Request::Headers
        conn.use SOAP::Middleware::Response::Parse, name: "HCA-ES"
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
