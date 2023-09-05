# frozen_string_literal: true

module V0
  class TermsOfUseAgreementsController < ApplicationController
    before_action :set_user_account
    before_action :set_terms_of_use_agreement

    STATSD_PREFIX = 'api.terms_of_use_agreements'

    def accept
      @terms_of_use_agreement.accepted!
      render_success
    rescue ActiveRecord::RecordInvalid
      render_error
    end

    def decline
      @terms_of_use_agreement.declined!
      render_success
    rescue ActiveRecord::RecordInvalid
      render_error
    end

    private

    def set_user_account
      @user_account = current_user.user_account
    end

    def set_terms_of_use_agreement
      @terms_of_use_agreement = @user_account.terms_of_use_agreements.new(agreement_version: params[:version])
    end

    def render_success
      render json: { terms_of_use_agreement: @terms_of_use_agreement }, status: :created
      log_success
    end

    def render_error
      render json: { error: @terms_of_use_agreement.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end

    def log_success
      context = {
        terms_of_use_agreement_id: @terms_of_use_agreement.id,
        user_account_uuid: @user_account.id,
        icn: @user_account.icn,
        agreement_version: @terms_of_use_agreement.agreement_version,
        response: @terms_of_use_agreement.response
      }

      Rails.logger.info("[TermsOfUseAgreementsController] [#{@terms_of_use_agreement.response}]", context)

      StatsD.increment("#{STATSD_PREFIX}.#{@terms_of_use_agreement.response}",
                       tags: ["agreement_version:#{@terms_of_use_agreement.agreement_version}"])
    end
  end
end
