# frozen_string_literal: true

require 'claims_api/form_schemas'

module ClaimsApi
  module V2
    class Base < ClaimsApi::V2::ApplicationController
      private

      def validate_json_schema
        validator = ClaimsApi::FormSchemas.new
        validator.validate!(self.class::FORM_NUMBER, form_attributes)
      end

      def form_attributes
        @json_body.dig('data', 'attributes') || {}
      end
    end
  end
end
