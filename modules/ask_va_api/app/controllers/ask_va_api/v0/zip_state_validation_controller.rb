# frozen_string_literal: true

module AskVAApi
  module V0
    class ZipStateValidationController < ApplicationController
      def create
        result = ZipStateValidator.call(
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
