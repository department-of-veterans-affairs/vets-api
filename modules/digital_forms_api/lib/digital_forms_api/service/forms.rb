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

      # GET a form template
      def template(form_id)
        perform :get, "forms/#{form_id}/template", {}, {}
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
