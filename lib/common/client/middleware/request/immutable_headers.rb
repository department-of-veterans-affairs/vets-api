# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Request
        class ImmutableHeaders < Faraday::Middleware
          HTTP_PROTOCOL_HEADERS = Set.new %w[
            Accept
            Accept-Charset
            Accept-Encoding
            Accept-Language
            Accept-Ranges
            Age
            Allow
            Authorization
            Cache-Control
            Connection
            Content-Encoding
            Content-Language
            Content-Length
            Content-Location
            Content-MD5
            Content-Range
            Content-Type
            Date
            ETag
            Expect
            Expires
            From
            Host
            If-Match
            If-Modified-Since
            If-None-Match
            If-Range
            If-Unmodified-Since
            Last-Modified
            Location
            Max-Forwards
            Pragma
            Proxy-Authenticate
            Proxy-Authorization
            Range
            Referer
            Retry-After
            Server
            TE
            Trailer
            Transfer-Encoding
            Upgrade
            User-Agent
            Vary
            Via
          ]

          def call(env)
            headers = {}
            env.request_headers.each do |k, v|
              if HTTP_PROTOCOL_HEADERS.include?(k)
                headers[k] = v
              else
                headers[CoreExtensions::ImmutableString.new(k)] = v
              end
            end
            env.request_headers = headers
            @app.call(env)
          end
        end
      end
    end
  end
end
