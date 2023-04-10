# frozen_string_literal: true

require 'mockdata/mpi/find'

module MockedAuthentication
  module MPI
    class MockdataController < MockedAuthentication::ApplicationController
      include ActionController::HttpAuthentication::Token::ControllerMethods
      skip_before_action :verify_authenticity_token
      before_action :mockdata_authorize

      rescue_from ActionController::BadRequest do |e|
        render json: { errors: e }, status: :bad_request
      end

      def show
        icn = mockdata_params[:icn]

        yml = Mockdata::MPI::Find.new(icn:).perform

        response_body = {
          data: {
            attributes: {
              icn:,
              yml:
            }
          }
        }

        render json: response_body, status: :ok
      rescue => e
        render json: { errors: e }, status: :bad_request
      end

      private

      def mockdata_params
        params.permit(:icn)
      end

      def mockdata_authorize
        authenticate_or_request_with_http_token do |token|
          token == Settings.sign_in.mockdata_sync_api_key
        end
      end
    end
  end
end
