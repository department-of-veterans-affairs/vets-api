# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Forms API
    class Forms < Base
      # GET a form schema
      def schema(form_id)
        perform :get, "forms/#{form_id}/schema", {}, {}
      end

      # GET a form template (with caching)
      def template(form_id)
        cache_key = "digital_forms_api:template:#{form_id}"
        cached = Rails.cache.read(cache_key)
        return cached if cached.present?

        response = perform :get, "forms/#{form_id}/template", {}, {}
        Rails.cache.write(cache_key, response, expires_in: 24.hours)
        response
      end

      private

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
