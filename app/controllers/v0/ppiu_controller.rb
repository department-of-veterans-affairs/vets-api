# frozen_string_literal: true

module V0
  class PPIUController < ApplicationController
    before_action { authorize :evss, :access? }

    def index
      response = service.get_payment_information
      render json: response,
             serializer: PPIUSerializer
    end

    private

    def service
      EVSS::PPIU::Service.new(@current_user)
    end
  end
end
