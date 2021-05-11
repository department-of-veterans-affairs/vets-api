# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ApplicationController
      skip_before_action :authenticate, only: %i[show]
      ICN_FOR_TEST_USER = '1012667145V762142'

      def show
        headers_to_validate = %w[Authorization X-VA-SSN X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date]
        validate_headers(headers_to_validate)

        render json: { icn: ICN_FOR_TEST_USER }
      end
    end
  end
end
