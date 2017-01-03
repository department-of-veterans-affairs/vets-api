# frozen_string_literal: true
require 'soap/middleware/request/headers'
require 'soap/middleware/response/parse'
require 'hca/settings'
require 'hca/enrollment_system'

module HCA
  class Service
    def submit_form(form)
      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(form)
      submission = soap.build_request(:save_submit_form, message: formatted)
      post(submission)
    end

    def health_check
      submission = soap.build_request(:get_form_submission_status, message:
        { formSubmissionId: HCA::Settings::HEALTH_CHECK_ID })
      response = post(submission)
      root = response.body.locate('S:Envelope/S:Body/retrieveFormSubmissionStatusResponse').first
      {
        id: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first.text
      }
    end

    def self.options
      opts = {
        url: HCA::Settings::ENDPOINT,
        ssl: {
          verify: true
        }
      }
      if HCA::Settings::CERT_STORE
        opts[:ssl][:cert_store] = HCA::Settings::CERT_STORE
      end
      if HCA::Settings::SSL_CERT && HCA::Settings::SSL_KEY
        opts[:ssl].merge!(client_cert: HCA::Settings::SSL_CERT,
                          client_key: HCA::Settings::SSL_KEY)
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
      Savon.client(wsdl: HCA::Settings::WSDL,
                   env_namespace: :soap,
                   element_form_default: :qualified,
                   namespaces: {
                     'xmlns:tns': 'http://va.gov/service/esr/voa/v1'
                   },
                   namespace: 'http://va.gov/schema/esr/voa/v1')
    end

    def connection
      @conn ||= Faraday.new(HCA::Service.options) do |conn|
        conn.options.open_timeout = 10  # TODO(molson): Make a config/setting
        conn.options.timeout = 15       # TODO(molson): Make a config/setting
        conn.use SOAP::Middleware::Request::Headers
        conn.use SOAP::Middleware::Response::Parse, name: 'HCA-ES'
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
