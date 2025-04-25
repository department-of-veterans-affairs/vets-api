# frozen_string_literal: true

require 'evss/ppiu/service'
require 'lighthouse/direct_deposit/client'
require 'lighthouse/direct_deposit/payment_account'
require 'lighthouse/direct_deposit/error_parser'
require_relative '../concerns/sso_logging'

module Mobile
  module V0
    class PaymentInformationController < ApplicationController
      include Mobile::Concerns::SSOLogging

      before_action { authorize :evss, :access? unless lighthouse? }
      before_action { authorize :ppiu, :access? unless lighthouse? }
      before_action { authorize :lighthouse, :mobile_access? if lighthouse? }

      before_action :validate_pay_info, only: :update
      before_action(only: :update) { authorize(:ppiu, :access_update?) unless lighthouse? }
      after_action(only: :update) { evss_proxy.send_confirmation_email unless lighthouse? }
      after_action(only: :update) { send_lighthouse_confirmation_email if lighthouse? }

      def index
        payment_information = if lighthouse?
                                data = lighthouse_service.get_payment_info
                                validate_response!(data)
                                adapted_data = lighthouse_adapter.parse(data, current_user.uuid)
                                Mobile::V0::PaymentInformation.new(adapted_data)
                              else
                                data = evss_proxy.get_payment_information
                                Mobile::V0::PaymentInformation.legacy_create_from_upstream(data, current_user.uuid)
                              end
        render json: Mobile::V0::PaymentInformationSerializer.new(payment_information)
      end

      def update
        lh_error_response = nil

        payment_information = if lighthouse?
                                begin
                                  data = lighthouse_service.update_payment_info(pay_info)
                                  adapted_data = lighthouse_adapter.parse(data, current_user.uuid)
                                  Mobile::V0::PaymentInformation.new(adapted_data)
                                rescue Common::Exceptions::BaseError => e
                                  error = { status: e.status_code, body: e.errors.first }
                                  lh_error_response = Mobile::V0::Adapters::LighthouseDirectDepositError.parse(error)
                                end
                              else
                                data = evss_proxy.update_payment_information(pay_info)
                                Mobile::V0::PaymentInformation.legacy_create_from_upstream(data, current_user.uuid)
                              end

        if lh_error_response
          render status: lh_error_response.status, json: lh_error_response.body
        else
          render json: Mobile::V0::PaymentInformationSerializer.new(payment_information)
        end
      end

      private

      def evss_proxy
        @evss_proxy ||= Mobile::V0::LegacyPaymentInformation::Proxy.new(@current_user)
      end

      def evss_ppiu_params
        params.permit(
          :account_type,
          :financial_institution_name,
          :account_number,
          :financial_institution_routing_number
        )
      end

      def lighthouse_ppiu_params
        params[:routing_number] = params[:financial_institution_routing_number]
        params.permit(:account_type,
                      :account_number,
                      :routing_number)
      end

      def pay_info
        @pay_info ||= if lighthouse?
                        Lighthouse::DirectDeposit::PaymentAccount.new(lighthouse_ppiu_params)
                      else
                        EVSS::PPIU::PaymentAccount.new(evss_ppiu_params)
                      end
      end

      def lighthouse_service
        @lighthouse_service ||= DirectDeposit::Client.new(@current_user.icn)
      end

      def lighthouse_adapter
        Mobile::V0::Adapters::LighthouseDirectDeposit.new
      end

      def lighthouse?
        Flipper.enabled?(:mobile_lighthouse_direct_deposit, @current_user)
      end

      def validate_pay_info
        unless pay_info.valid?
          Sentry.set_tags(validation: 'direct_deposit')
          raise Common::Exceptions::ValidationErrors, pay_info
        end
      end

      def send_lighthouse_confirmation_email
        VANotifyDdEmailJob.send_to_emails(@current_user.all_emails)
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
