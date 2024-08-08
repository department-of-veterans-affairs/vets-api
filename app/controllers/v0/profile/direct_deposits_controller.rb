# frozen_string_literal: true

require 'lighthouse/service_exception'
require 'lighthouse/direct_deposit/client'
require 'lighthouse/direct_deposit/error_parser'
require 'lighthouse/direct_deposit/payment_account'
require 'lighthouse/direct_deposit/control_information'

module V0
  module Profile
    class DirectDepositsController < ApplicationController
      service_tag 'direct-deposit'
      before_action { authorize :lighthouse, :direct_deposit_access? }

      after_action :log_sso_info, only: :update

      rescue_from(*Lighthouse::ServiceException::ERROR_MAP.values) do |exception|
        error = { status: exception.status_code, body: exception.errors.first }
        response = Lighthouse::DirectDeposit::ErrorParser.parse(error)

        # temporary - will be removed after direct deposit merge is complete
        update_error_code_prefix(response) if single_form_enabled?

        render status: response.status, json: response.body
      end

      def show
        response = client.get_payment_info

        render json: DisabilityCompensationsSerializer.new(response.body), status: response.status
      end

      def update
        set_payment_account(payment_account_params)

        response = client.update_payment_info(@payment_account)
        send_confirmation_email

        render json: DisabilityCompensationsSerializer.new(response.body), status: response.status
      end

      private

      def single_form_enabled?
        Flipper.enabled?(:profile_show_direct_deposit_single_form, @current_user)
      end

      def update_error_code_prefix(response)
        response.code = response.code.sub('cnp.payment', 'direct.deposit')
      end

      def client
        @client ||= DirectDeposit::Client.new(@current_user.icn)
      end

      def set_payment_account(params)
        @payment_account ||= Lighthouse::DirectDeposit::PaymentAccount.new(params)
      end

      def payment_account_params
        params.require(:payment_account)
              .permit(:account_type,
                      :account_number,
                      :routing_number)
      end

      def send_confirmation_email
        VANotifyDdEmailJob.send_to_emails(current_user.all_emails)
      end
    end
  end
end
