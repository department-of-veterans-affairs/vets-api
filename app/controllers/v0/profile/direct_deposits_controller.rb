# frozen_string_literal: true

require 'lighthouse/service_exception'
require 'lighthouse/direct_deposit/client'
require 'lighthouse/direct_deposit/error_parser'
require 'lighthouse/direct_deposit/payment_account'

module V0
  module Profile
    class DirectDepositsController < ApplicationController
      service_tag 'direct-deposit'
      # before_action { authorize :lighthouse, :direct_deposit_access? }

      after_action :log_sso_info, only: :update

      rescue_from(*Lighthouse::ServiceException::ERROR_MAP.values) do |exception|
        error = { status: exception.status_code, body: exception.errors.first }
        response = Lighthouse::DirectDeposit::ErrorParser.parse(error)

        if response.status.between?(500, 599)
          Rails.logger.error("Direct Deposit API error: #{exception.message}", {
                               error_class: exception.class.to_s,
                               error_message: exception.message,
                               user_uuid: @current_user&.uuid,
                               backtrace: exception.backtrace.first(3)&.join(' | ')
                             })
        end

        render status: response.status, json: response.body
      end

      def show
        # response = client.get_payment_info
        response = mock_fetch_response
        render json: DirectDepositsSerializer.new(response.body), status: response.status
      end

      def update
        set_payment_account(payment_account_params)

        response = client.update_payment_info(@payment_account)
        send_confirmation_email

        render json: DirectDepositsSerializer.new(response.body), status: response.status
      end

      private

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

      def mock_fetch_response
        mock_body = {
          'control_information' => {
            'can_update_direct_deposit' => true,
            'is_corp_available' => true,
            'is_edu_claim_available' => true,
            'has_cp_claim' => true,
            'has_cp_award' => true,
            'is_corp_rec_found' => true,
            'has_no_bdn_payments' => true,
            'has_index' => true,
            'is_competent' => true,
            'has_mailing_address' => true,
            'has_no_fiduciary_assigned' => true,
            'is_not_deceased' => true,
            'has_payment_address' => true,
            'has_identity' => true
          },
          'payment_account' => {
            'financial_institution_name' => 'WELLS FARGO BANK',
            'account_type' => 'Savings',
            'account_number' => '1234567890',
            'financial_institution_routing_number' => '021000021'
          }
        }
        mock_response = OpenStruct.new(status: 200, body: mock_body)
        Lighthouse::DirectDeposit::PaymentInfoParser.parse(mock_response)
      end
    end
  end
end
