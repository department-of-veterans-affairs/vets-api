# frozen_string_literal: true
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/errors'
require 'bb/generate_report_request_form'
require 'bb/configuration'
require 'rx/client_session'
require 'typhoeus'

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
    def get_download_report(doctype, header_callback, yielder)
      # TODO: For testing purposes, use one of the following static files:
      # uri = URI("#{Settings.mhv.rx.host}/vetsgov/1mb.file")
      # uri = URI("#{Settings.mhv.rx.host}/vetsgov/90mb.file")
      uri = URI.join(base_path, "bluebutton/bbreport/#{doctype}")
      request = Typhoeus::Request.new(uri.to_s, headers: @api_client.token_headers,
                                                connecttimeout: 10)
      request.on_headers do |response|
        raise Common::Client::Errors::ClientError, 'Health record request timed out' if response.timed_out?
        raise Common::Client::Errors::ClientError, "Health record request failed: #{response.code}" if
          response.code != 200
        header_callback.call(response.headers)
      end

      request.on_body do |chunk|
        yielder << chunk
      end

      request.on_complete do |response|
        raise Common::Client::Errors::StreamingError, "Health record stream failed: #{response.return_message}" unless
          response.success?
      end

      request.run
    end
  end
end
