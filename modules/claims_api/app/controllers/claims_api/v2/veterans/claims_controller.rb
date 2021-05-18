# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        # TODO: REMOVE BEFORE IMPLEMENTATION
        skip_before_action :authenticate, only: %i[index]
        ICN_FOR_TEST_USER = '1012667145V762142'
        # TODO: REMOVE BEFORE IMPLEMENTATION

        def index
          raise ::Common::Exceptions::Unauthorized if request.headers['Authorization'].blank?
          unless params[:veteran_id] == ICN_FOR_TEST_USER
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found')
          end

          render json: JSON.parse(
            File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'usability_testing_claims.json'))
          )
        end
      end
    end
  end
end
