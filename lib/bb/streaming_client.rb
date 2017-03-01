# frozen_string_literal: true
require 'common/client/concerns/mhv_session_based_client'
require 'bb/generate_report_request_form'
require 'bb/configuration'
require 'rx/client_session'

module BB
  # Core class responsible for api interface operations
  class StreamingClient
    include Common::Client::MHVSessionBasedClient

    def initialize(api_client)
      @api_client = api_client
    end

    def base_path
      @api_client.class.configuration.base_path
    end

    # doctype must be one of: txt or pdf
    def get_download_report(doctype, headers, yielder)
      uri = URI('https://essapi-sysb.myhealth.va.gov/vetsgov/90mb.file')
      # uri = URI.join(base_path, "bluebutton/bbreport/#{doctype}")
      request = Net::HTTP::Get.new(uri)
      @api_client.token_headers.each do |k, v|
        request[k] = v
      end
      Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https')) do |http|
        http.request request do |response|
          headers.keys.each do |k|
            headers[k] = response[k]
          end
          response.read_body do |chunk|
            yielder << chunk
          end
        end
      end
    end
  end
end
