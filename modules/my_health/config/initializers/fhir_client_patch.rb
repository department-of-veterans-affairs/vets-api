# frozen_string_literal: true

# Combined monkeypatches for the Ruby FHIR client
# Includes:
# - Custom headers for search, read, and next_page
#
# Patched version: department-of-veterans-affairs/fhir_client (fork of 5.0.3)

module FHIR
  ##
  # These patches allow FHIR calls to take custom headers. This is to allow us to bypass the FHIR
  # server's cache when requesting a FHIR resource. It also allows us to inject the x-api-key header
  # when accessing FHIR via the MHV API Gateway.
  #
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

    module Feed
      def next_page(current, options = {}, page = FORWARD)
        bundle = current.resource
        link = bundle.method(page).call
        return nil unless link

        extra_headers = options[:headers] || {}

        reply = get strip_base(link.url), fhir_headers.merge(extra_headers)
        reply.resource = parse_reply(current.resource_class, @default_format, reply)
        reply.resource_class = current.resource_class
        reply
      end
    end

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
