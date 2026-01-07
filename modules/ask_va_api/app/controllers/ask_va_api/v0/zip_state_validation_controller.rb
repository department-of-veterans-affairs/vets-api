# frozen_string_literal: true

module AskVAApi
  module V0
    class ZipStateValidationController < ApplicationController
      around_action :handle_exceptions
      skip_before_action :authenticate, only: :create

      def create
        result = AskVAApi::ZipStateValidation::ZipStateValidator.call(
          zip_code: params[:zip_code],
          state_code: params[:state_code]
        )

        render json: {
          valid: result.valid,
          error_code: result.error_code,
          error_message: result.error_message
        }
      end
    end
  end
end
