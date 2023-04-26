# frozen_string_literal: true

require 'evss/ppiu/service'
require_relative '../concerns/sso_logging'

module Mobile
  module V0
    class PaymentInformationController < ApplicationController
      include Mobile::Concerns::SSOLogging

      before_action { authorize :evss, :access? }
      before_action { authorize :ppiu, :access? }
      before_action :validate_pay_info, only: :update
      before_action(only: :update) { authorize(:ppiu, :access_update?) }
      after_action(only: :update) { proxy.send_confirmation_email }

      def index
        payment_information = proxy.get_payment_information
        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.uuid,
                                                                  payment_information.payment_account,
                                                                  payment_information.control_information)
      end

      def update
        payment_information = proxy.update_payment_information(pay_info)
        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.uuid,
                                                                  payment_information.payment_account,
                                                                  payment_information.control_information)
      end

      private

      def proxy
        @proxy ||= Mobile::V0::PaymentInformation::Proxy.new(@current_user)
      end

      def ppiu_params
        params.permit(
          :account_type,
          :financial_institution_name,
          :account_number,
          :financial_institution_routing_number
        )
      end

      def pay_info
        @pay_info ||= EVSS::PPIU::PaymentAccount.new(ppiu_params)
      end

      def validate_pay_info
        unless pay_info.valid?
          Raven.tags_context(validation: 'direct_deposit')
          raise Common::Exceptions::ValidationErrors, pay_info
        end
      end
    end
  end
end
