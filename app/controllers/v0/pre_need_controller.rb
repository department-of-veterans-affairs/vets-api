module V0
  class PreNeedController < ApplicationController
    
    def submit
      payload = params.permit!.to_h

      response = Mulesoft::PreNeed::Service.new.submit_pre_need(payload)

      render json: response.body, status: response.status
    rescue => e
      Rails.logger.error("[PreNeedController] Error: #{e.message}")
      render json: { error: e.message }, status: 500
    end
  end
end
