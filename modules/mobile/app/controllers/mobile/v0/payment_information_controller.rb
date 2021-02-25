# frozen_string_literal: true

require 'evss/ppiu/service'

module Mobile
  module V0
    class PaymentInformationController < ApplicationController
      before_action { authorize :evss, :access? }
      before_action { authorize :ppiu, :access? }
      before_action :validate_pay_info, only: :update
      before_action(only: :update) { authorize(:ppiu, :access_update?) }

      def index
        payment_information = service.get_payment_information.responses[0]
        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.id,
                                                                  payment_information.payment_account,
                                                                  payment_information.control_information)
      end

      def update
        payment_information = service.update_payment_information(pay_info).responses[0]
        send_confirmation_email
        render json: Mobile::V0::PaymentInformationSerializer.new(@current_user.id,
                                                                  payment_information.payment_account,
                                                                  payment_information.control_information)
      end

      private

      def service
        @service ||= EVSS::PPIU::Service.new(@current_user)
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

      def send_confirmation_email
        user_emails = current_user.all_emails

        if user_emails.present?
          user_emails.each do |email|
            DirectDepositEmailJob.perform_async(email, params[:ga_client_id])
          end
        else
          log_message_to_sentry(
            'Direct Deposit info update: no email address present for confirmation email',
            :info,
            {},
            feature: 'direct_deposit'
          )
        end
      end
    end
  end
end
