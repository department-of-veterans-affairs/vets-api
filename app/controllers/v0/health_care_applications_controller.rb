# frozen_string_literal: true

require 'hca/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    include HcaValidate

    def create
      authenticate_token

      form = JSON.parse(params[:form])
      validate!(form)

      result = begin
        HCA::Service.new(current_user).submit_form(form)
      rescue HCA::SOAPParser::ValidationError => e
        raise Common::Exceptions::BackendServiceException.new(
          nil, detail: e.message
        )
      rescue Common::Client::Errors::ClientError => e
        log_exception_to_sentry(e)

        raise Common::Exceptions::BackendServiceException.new(
          nil, detail: e.message
        )
      end

      clear_saved_form(HcaValidate::FORM_ID)

      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"
      render(json: result)
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end

    private

    def skip_sentry_exception_types
      super + [Common::Exceptions::GatewayTimeout]
    end
  end
end
