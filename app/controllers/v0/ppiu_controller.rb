# frozen_string_literal: true

module V0
  class PPIUController < ApplicationController
    before_action { authorize :evss, :access? }
    before_action :validate_pay_info, only: :update

    def index
      response = service.get_payment_information
      render json: response,
             serializer: PPIUSerializer
    end

    def update
      response = service.update_payment_information(pay_info)
      send_confirmation_email
      render json: response,
             serializer: PPIUSerializer
    end

    private

    def service
      EVSS::PPIU::Service.new(@current_user)
    end

    def ppiu_params
      params.permit(
        :account_type,
        :financial_institution_name,
        :account_number,
        :financial_institution_routing_number
      )
    end

    def current_user_email
      vet360_email =
        begin
          current_user.vet360_contact_info&.email&.email_address
        rescue
          nil
        end
      vet360_email || current_user.email
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
      if current_user_email
        DirectDepositEmailJob.perform_async(current_user_email, params[:ga_client_id])
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
