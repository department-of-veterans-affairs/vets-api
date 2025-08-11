# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'json'

module ClaimsApi
  module V2
    module Veterans
      class Base < ClaimsApi::V2::ApplicationController
        include ClaimsApi::V2::JsonFormatValidation

        before_action :validate_json_format, if: -> { request.post? }

        private

        def validate_json_schema(form_number = self.class::FORM_NUMBER)
          validator = ClaimsApi::FormSchemas.new(schema_version: 'v2')
          validator.validate!(form_number, form_attributes)
        end

        def form_attributes
          @json_body&.dig('data', 'attributes') || {}
        end

        def claim_transaction_id
          @json_body&.dig('meta', 'transactionId') || nil
        end

        def validate_veteran_name(require_first_and_last)
          first_name_blank = target_veteran.first_name.blank?
          last_name_blank = target_veteran.last_name.blank?
          if require_first_and_last
            if first_name_blank && last_name_blank
              raise_exception_name_error('Missing first and last name')
            elsif first_name_blank
              raise_exception_name_error('Missing first name')
            elsif last_name_blank
              raise_exception_name_error('Missing last name')
            end
          elsif first_name_blank && last_name_blank
            raise_exception_name_error('Must have either first or last name')
          end
        end

        def raise_exception_name_error(message)
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
        end
      end
    end
  end
end
