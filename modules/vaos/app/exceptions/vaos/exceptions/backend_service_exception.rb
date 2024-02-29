# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Exceptions
    class BackendServiceException < Common::Exceptions::BackendServiceException
      # rubocop:disable Style/MutableConstant
      VAOS_ERRORS = {
        400 => 'VAOS_400',
        403 => 'VAOS_403',
        404 => 'VAOS_404',
        409 => 'VAOS_409A',
        500 => 'VAOS_502',
        501 => 'VAOS_502',
        502 => 'VAOS_502',
        503 => 'VAOS_502',
        504 => 'VAOS_502',
        505 => 'VAOS_502',
        506 => 'VAOS_502',
        507 => 'VAOS_502',
        508 => 'VAOS_502',
        509 => 'VAOS_502',
        510 => 'VAOS_502'
      }

      VAOS_ERRORS.default = 'VA900'

      def initialize(env)
        @env = env
        key = VAOS_ERRORS[env.status]
        super(key, response_values, env.status, env.body)
      end

      def response_values
        {
          detail: detail(@env.body),
          source: { vamf_url: anonymize_icn(@env.url), vamf_body: @env.body, vamf_status: @env.status }
        }
      end

      private

      def detail(body)
        parsed = JSON.parse(body)
        if parsed['errors']
          parsed['errors'].first['errorMessage']
        else
          parsed['message']
        end
      rescue
        body
      end

      # Anonymizes the ICN present in a given URI object by substituting a SHA256 digest for the ICN.
      # If an ICN is not present in the URL,  it would simply return the original URI.
      #
      # @param url [URI::Generic] URI in which ICN needs to be anonymized.
      #
      # @return [URI::Generic] URI with anonymized ICN (If present), original URI otherwise.
      #
      def anonymize_icn(uri)
        return uri if uri.nil?

        # Extract the patient ICN part from the URL
        url = uri.to_s
        match = url[/(\d{10}V\d{6})/]

        return uri unless match

        digest = Digest::SHA256.hexdigest(match)
        url.gsub!(match, digest)
        URI(url)
      end
      # rubocop:enable Style/MutableConstant
    end
  end
end
