# frozen_string_literal: true

require 'evss/ppiu/service'
require 'lighthouse/direct_deposit/client'
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
                                lighthouse_adapter.parse(lighthouse_service.get_payment_info)
                              else
                                evss_proxy.get_payment_information
                              end
        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.uuid,
                                                                  payment_information.payment_account,
                                                                  payment_information.control_information)
      end

      def update
        payment_information = if lighthouse?
                                lighthouse_adapter.parse(lighthouse_service.update_payment_info(pay_info))
                              else
                                evss_proxy.update_payment_information(pay_info)
                              end

        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.uuid,
                                                                  payment_information.payment_account,
                                                                  payment_information.control_information)
      end

      private

      def evss_proxy
        @evss_proxy ||= Mobile::V0::PaymentInformation::Proxy.new(@current_user)
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
          Raven.tags_context(validation: 'direct_deposit')
          raise Common::Exceptions::ValidationErrors, pay_info
        end
      end

      def send_lighthouse_confirmation_email
        VANotifyDdEmailJob.send_to_emails(@current_user.all_emails, :comp_and_pen)
      end
    end
  end
end
