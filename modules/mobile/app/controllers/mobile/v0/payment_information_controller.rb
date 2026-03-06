# frozen_string_literal: true

require 'lighthouse/direct_deposit/client'
require 'lighthouse/direct_deposit/payment_account'
require 'lighthouse/direct_deposit/error_parser'
require_relative '../concerns/sso_logging'

module Mobile
  module V0
    class PaymentInformationController < ApplicationController
      include Mobile::Concerns::SSOLogging

      before_action { authorize :lighthouse, :mobile_access? }
      before_action :validate_pay_info, only: :update
      after_action(only: :update) { send_confirmation_email }

      def index
        data = lighthouse_service.get_payment_info
        validate_response!(data)
        adapted_data = lighthouse_adapter.parse(data, current_user.uuid)
        payment_information = Mobile::V0::PaymentInformation.new(adapted_data)

        render json: Mobile::V0::PaymentInformationSerializer.new(payment_information)
      end

      def update
        data = lighthouse_service.update_payment_info(pay_info)
        adapted_data = lighthouse_adapter.parse(data, current_user.uuid)
        payment_information = Mobile::V0::PaymentInformation.new(adapted_data)
        render json: Mobile::V0::PaymentInformationSerializer.new(payment_information)
      rescue Common::Exceptions::BaseError => e
        error = { status: e.status_code, body: e.errors.first }
        lh_error_response = Mobile::V0::Adapters::LighthouseDirectDepositError.parse(error)
        render status: lh_error_response.status, json: lh_error_response.body
      end

      private

      def payment_information_params
        params[:routing_number] = params[:financial_institution_routing_number]
        params.permit(:account_type,
                      :account_number,
                      :routing_number)
      end

      def pay_info
        @pay_info ||= Lighthouse::DirectDeposit::PaymentAccount.new(payment_information_params)
      end

      def lighthouse_service
        @lighthouse_service ||= DirectDeposit::Client.new(@current_user.icn)
      end

      def lighthouse_adapter
        Mobile::V0::Adapters::LighthouseDirectDeposit.new
      end

      def validate_pay_info
        unless pay_info.valid?
          Sentry.set_tags(validation: 'direct_deposit')
          raise Common::Exceptions::ValidationErrors, pay_info
        end
      end

      def send_confirmation_email
        if @current_user.icn.present?
          all_emails = @current_user.all_emails
          VANotifyDdEmailJob.send_to_emails(all_emails)
        else
          Rails.logger.info('Mobile::V0::PaymentInformation#send_confirmation_email NO ICN for user')
        end
      end

      # this handles a bug that has been observed in datadog.
      # lighthouse has been informed that this is happening and will hopefully fix it soon.
      # remove this code if the detail messages below do not exist in the logs
      def validate_response!(data)
        errors = []
        errors << "Control information missing for user #{current_user.uuid}" if data.control_information.nil?
        errors << "Payment account info missing for user #{current_user.uuid}" if data.payment_account.nil?
        return if errors.empty?

        raise Common::Exceptions::UnprocessableEntity.new(detail: errors.join('. '))
      end
    end
  end
end
