# frozen_string_literal: true

module Common
  module Client
    module Concerns
      module StreamingClient
        extend ActiveSupport::Concern

        def streaming_get(uri, headers, header_callback, yielder)
          request = Net::HTTP::Get.new(uri)
          headers.each { |k, v| request[k] = v }
          begin
            Net::HTTP.start(uri.host, uri.port, read_timeout: 20, use_ssl: (uri.scheme == 'https')) do |http|
              http.request request do |response|
                if response.is_a?(Net::HTTPClientError) || response.is_a?(Net::HTTPServerError)
                  raise Common::Client::Errors::ClientError, "Streaming request failed: #{response.code}"
                end

                header_callback.call response.canonical_each
                response.read_body do |chunk|
                  yielder << chunk
                end
              end
            end
          rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
                 Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
            raise Common::Client::Errors::ClientError, "Streaming request failed: #{e.message}"
          end
        end
      end
    end
  end
end
