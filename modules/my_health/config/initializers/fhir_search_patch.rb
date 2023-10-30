# frozen_string_literal: true

# Monkeypatch to allow fhir_search to take custom headers. This is to allow us to bypass the FHIR
# server's cache when requesting a Patient resource.
# Patched version: fhir_client (5.0.3)
module FHIR
  module Sections
    module Search
      def search(klass, options = {}, format = @default_format)
        options[:resource] = klass
        options[:format] = format

        extra_headers = options[:headers] || {}

        reply = if options.dig(:search, :flag) != true && options.dig(:search, :body).nil?
                  get resource_url(options), fhir_headers.merge(extra_headers)
                else
                  options[:search][:flag] = true
                  post resource_url(options), options.dig(:search, :body),
                       fhir_headers({ content_type: 'application/x-www-form-urlencoded' }).merge(extra_headers)
                end

        reply.resource = parse_reply(klass, format, reply)
        reply.resource_class = klass
        reply
      end
    end
  end
end
