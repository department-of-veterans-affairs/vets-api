# frozen_string_literal: true

require 'lighthouse/direct_deposit/client'
require 'lighthouse/direct_deposit/payment_account'

module V0
  module Profile
    module DirectDeposits
      class DisabilityCompensationsController < ApplicationController
        before_action :controller_enabled?
        before_action { authorize :lighthouse, :access_disability_compensations? }

        def show
          response = client.get_payment_info

          render status: response.status,
                 json: response.body,
                 serializer: DisabilityCompensationsSerializer
        end

        private

        def controller_enabled?
          routing_error unless Flipper.enabled?(:profile_lighthouse_direct_deposit, @current_user)
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
          VANotifyDdEmailJob.send_to_emails(current_user.all_emails, :comp_and_pen)
        end
      end
    end
  end
end
