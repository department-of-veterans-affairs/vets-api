# frozen_string_literal: true

# Monkeypatch to allow read to take custom headers. This allows us to inject the x-api-key header
# when accessing FHIR via the MHV API Gateway.
# Patched version: department-of-veterans-affairs/fhir_client (fork of 5.0.3)
module FHIR
  module Sections
    module Crud
      def read(klass, id, format = nil, summary = nil, options = {})
        options = { resource: klass, id:, format: format || @default_format }.merge(options)
        options[:summary] = summary if summary

        # Build the default headers (using the provided format if any)
        base_headers = {}
        base_headers[:accept] = format.to_s if format

        # Grab any custom headers provided in the options
        extra_headers = options[:headers] || {}

        # Merge custom headers into the default FHIR headers
        reply = get resource_url(options), fhir_headers(base_headers).merge(extra_headers)

        reply.resource = parse_reply(klass, format || @default_format, reply)
        reply.resource_class = klass
        reply
      end
    end
  end
end
