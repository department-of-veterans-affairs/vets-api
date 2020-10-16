# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'evss/ppiu/service'

module Mobile
  module V0
    class PaymentInformationController < ApplicationController
      before_action { authorize :evss, :access? }
      before_action { authorize :ppiu, :access? }

      def index
        payment_information = service.get_payment_information
        binding.pry
        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.id, payment_information.responses[0].payment_account)
      end

      def update
        render "update endpoint"
      end

      def service
        @service ||= EVSS::PPIU::Service.new(@current_user)
      end
    end
  end
end
