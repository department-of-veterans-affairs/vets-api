# frozen_string_literal: true

module AskVAApi
  module V0
    class ZipStateValidationController < ApplicationController
      def create
        result = ZipStateValidator.call(
          zipcode: params[:zipcode],
          state_name: params[:state_name]
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
