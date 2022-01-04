# frozen_string_literal: true

require 'evss/ppiu/service'

module V0
  class PPIUController < ApplicationController
    before_action { authorize :evss, :access? }
    before_action { authorize :ppiu, :access? }
    before_action :validate_pay_info, only: :update
    before_action(only: :update) { authorize(:ppiu, :access_update?) }

    def index
      response = service.get_payment_information
      render json: response,
             serializer: PPIUSerializer
    end

    def update
      response = service.update_payment_information(pay_info)
      Rails.logger.warn('PPIUController#update request completed', sso_logging_info)
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
      if Flipper.enabled?(:direct_deposit_vanotify, current_user)
        VANotifyDdEmailJob.send_to_emails(current_user.all_emails, :comp_pen)
      else
        DirectDepositEmailJob.send_to_emails(current_user.all_emails, params[:ga_client_id], :comp_pen)
      end
    end
  end
end
