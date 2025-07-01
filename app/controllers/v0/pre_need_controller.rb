module V0
  class PreNeedController < ApplicationController
    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    def submit
      Rails.logger.info("[PreNeedController] submit action called. Params: ")
      Rails.logger.info(params.inspect)
      Rails.logger.info("[PreNeedController] Settings.mulesoft.pre_need.mock: #{Settings.mulesoft.pre_need.mock}")

      payload = params.permit!.to_h

      # Check if mock is enabled in settings
      if Settings.mulesoft.pre_need.mock
        # Return a mock response
        mock_response = {
          "status" => "success",
          "message" => "This is a mocked PreNeed response.",
          "data" => payload
        }
        render json: mock_response, status: 200
        return
      end

      response = Mulesoft::PreNeed::Service.new.submit_pre_need(payload)
      render json: response.body, status: response.status
    rescue => e
      Rails.logger.error("[PreNeedController] Error: #{e.message}")
      render json: { error: e.message }, status: 500
    end
  end
end
