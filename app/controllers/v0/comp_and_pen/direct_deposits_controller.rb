# frozen_string_literal: true

require 'lighthouse/direct_deposit/service'
require 'lighthouse/direct_deposit/payment_account'

module V0
  module CompAndPen
    class DirectDepositsController < ApplicationController
      before_action :controller_enabled?
      before_action { authorize :lighthouse, :access_direct_deposit? }
      before_action :validate_payment_account, only: :update

      def show
        response = service.get
        render status: response.status,
               json: response.body,
               serializer: CompAndPenDirectDepositSerializer
      end

      def update
        response = service.update payment_account_params

        render status: response.status,
               json: response.body,
               serializer: CompAndPenDirectDepositSerializer
      end

      private

      def controller_enabled?
        routing_error unless Flipper.enabled?(:profile_lighthouse_direct_deposit, @current_user)
      end

      def service
        @service ||= DirectDeposit::Service.new(@current_user.icn)
      end

      def payment_account_params
        params.permit(:account_type, :account_number, :routing_number)
      end

      def payment_account
        @payment_account ||= Lighthouse::DirectDeposit::PaymentAccount.new(payment_account_params)
      end

      def validate_payment_account
        unless payment_account.valid?
          Raven.tags_context(validation: 'direct_deposit')
          raise Common::Exceptions::ValidationErrors, payment_account
        end
      end
    end
  end
end
