# frozen_string_literal: true

module V0
  class PPIUController < ApplicationController
    before_action { authorize :evss, :access? }

    def index
      response = service.get_payment_information
      render json: response,
             serializer: PPIUSerializer
    end

    def update
      pay_info = EVSS::PPIU::PaymentAccount.new(ppiu_params)
      raise Common::Exceptions::ValidationErrors, pay_info unless pay_info.valid?
      response = service.update_payment_information(pay_info)
      render json: response,
             serializer: PPIUSerializer
    end

    private

    def service
      EVSS::PPIU::Service.new(@current_user)
    end

    def ppiu_params
      params.permit(
        :account_type,
        :financial_institution_name,
        :account_number,
        :financial_institution_routing_number
      )
    end
  end
end
