# frozen_string_literal: true

require 'evss/ppiu/service'

module V0
  class PPIUController < ApplicationController
    service_tag 'direct-deposit'
    before_action :controller_enabled?
    before_action { authorize :evss, :access? }
    before_action { authorize :ppiu, :access? }
    before_action :validate_pay_info, only: :update
    before_action(only: :update) { authorize(:ppiu, :access_update?) }

    def controller_enabled?
      if Flipper.enabled?(:profile_ppiu_reject_requests, @current_user)
        message = 'EVSS PPIU endpoint is being deprecated. Please contact the ' \
                  'Authenticated Experience team with any questions or use the ' \
                  "'/v0/profile/direct_deposits' endpoint instead."

        raise Common::Exceptions::Forbidden, detail: message
      end
    end

    def index
      response = service.get_payment_information
      render json: PPIUSerializer.new(response)
    end

    def update
      response = service.update_payment_information(pay_info)
      Rails.logger.warn('PPIUController#update request completed', sso_logging_info)
      send_confirmation_email
      render json: PPIUSerializer.new(response)
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
        Sentry.set_tags(validation: 'direct_deposit')
        raise Common::Exceptions::ValidationErrors, pay_info
      end
    end

    def send_confirmation_email
      VANotifyDdEmailJob.send_to_emails(current_user.all_emails)
    end
  end
end
