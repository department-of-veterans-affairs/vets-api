# frozen_string_literal: true

require 'lighthouse/service_exception'
require 'lighthouse/direct_deposit/client'
require 'lighthouse/direct_deposit/error_parser'
require 'lighthouse/direct_deposit/payment_account'

module V0
  module Profile
    module DirectDeposits
      class DisabilityCompensationsController < ApplicationController
        service_tag 'direct-deposit'
        before_action { authorize :lighthouse, :access_disability_compensations? }
        after_action :log_sso_info, only: :update

        rescue_from(*Lighthouse::ServiceException::ERROR_MAP.values) do |exception|
          error = { status: exception.status_code, body: exception.errors.first }
          response = Lighthouse::DirectDeposit::ErrorParser.parse(error)

          log_stats(response)

          render status: response.status, json: response.body
        end

        def show
          response = client.get_payment_info

          render json: DisabilityCompensationsSerializer.new(response.body), status: response.status
        end

        def update
          response = client.update_payment_info(payment_account)
          send_confirmation_email
          render json: DisabilityCompensationsSerializer.new(response.body), status: response.status
        end

        private

        def log_stats(response)
          error = response.body[:errors]&.first
          StatsD.increment(error[:code]) if error
        end

        def client
          @client ||= DirectDeposit::Client.new(@current_user.icn)
        end

        def payment_account_params
          params.permit(:account_type, :account_number, :routing_number)
        end

        def payment_account
          @payment_account ||= Lighthouse::DirectDeposit::PaymentAccount.new(payment_account_params)
        end

        def send_confirmation_email
          VANotifyDdEmailJob.send_to_emails(current_user.all_emails, 'comp_and_pen')
        end
      end
    end
  end
end
