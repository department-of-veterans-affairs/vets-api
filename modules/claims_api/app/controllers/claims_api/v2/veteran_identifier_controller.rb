# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::Base
      skip_before_action :authenticate, only: %i[create]
      ICN_FOR_TEST_USER = '1012667145V762142'
      FORM_NUMBER = 'VETERAN_IDENTIFIER'

      def create
        validate_json_schema
        headers_to_validate = %w[Authorization]
        validate_headers(headers_to_validate)

        render json: { id: ICN_FOR_TEST_USER }
      end
    end
  end
end
