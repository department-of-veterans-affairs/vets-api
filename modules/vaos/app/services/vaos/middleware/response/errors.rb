# frozen_string_literal: true

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Middleware
        def on_complete(env)
          return if env.success?

          Sentry.set_extras(vamf_status: env.status, vamf_body: env.response_body, vamf_url: anonymize_icn(env.url))
          raise VAOS::Exceptions::BackendServiceException, env
        end

        private

        # Anonymizes the ICN present in a given URI object by substituting a SHA256 digest for the ICN.
        # If an ICN is not present in the URL,  it would simply return the original URI.
        #
        # @param url [URI] URI in which ICN needs to be anonymized.
        #
        # @return [URI] URI with anonymized ICN (If present), original URI otherwise.
        #
        def anonymize_icn(uri)
          return nil if uri.nil?

          # Extract the patient ICN part from the URL
          url = uri.to_s
          match = url[/(\d{10}V\d{6})/]

          return uri unless match

          digest = Digest::SHA256.hexdigest(match)
          url.gsub!(match, digest)
          URI(url)
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
