# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Forms API
    class Forms < Base
      # Cache TTL values for form templates. Production uses a longer TTL
      TEMPLATE_CACHE_TTL_PRODUCTION = 24.hours
      # Non-production environments use a shorter TTL
      TEMPLATE_CACHE_TTL_DEFAULT = 5.minutes

      # Build the cache key for a given form template.
      def self.template_cache_key(form_id)
        "digital_forms_api:template:#{form_id}"
      end

      # GET a form schema
      def schema(form_id)
        perform :get, "forms/#{form_id}/schema", {}, {}
      end

      # GET a form template (with caching)
      # Caches only the parsed response body to avoid persisting sensitive
      # request metadata (e.g., Authorization headers) from the Faraday::Env.
      def template(form_id)
        cache_key = self.class.template_cache_key(form_id)

        Rails.cache.fetch(cache_key, expires_in: template_cache_ttl, race_condition_ttl: 10.seconds) do
          perform(:get, "forms/#{form_id}/template", {}, {}).body
        end
      end

      private

      # Returns the cache TTL for form templates.
      # Production uses a longer TTL (24 hours); all other environments use a
      # shorter TTL (5 minutes) to avoid stale data during development and testing.
      def template_cache_ttl
        Rails.env.production? ? TEMPLATE_CACHE_TTL_PRODUCTION : TEMPLATE_CACHE_TTL_DEFAULT
      end

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'forms'
      end

      # end Forms
    end

    # end Service
  end

  # end DigitalFormsApi
end
