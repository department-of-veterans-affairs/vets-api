# frozen_string_literal: true

module V0
  class TermsOfUseAgreementsController < ApplicationController
    def accept
      terms_of_use_agreement = TermsOfUse::Acceptor.new(user_account: current_user.user_account,
                                                        version: params[:version]).perform!
      render_success(terms_of_use_agreement)
    rescue ActiveRecord::RecordInvalid, StandardError => e
      render_error(e.message)
    end

    def decline
      terms_of_use_agreement = TermsOfUse::Decliner.new(user_account: current_user.user_account,
                                                        version: params[:version]).perform!
      render_success(terms_of_use_agreement)
    rescue ActiveRecord::RecordInvalid, StandardError => e
      render_error(e.message)
    end

    private

    def render_success(terms_of_use_agreement)
      render json: { terms_of_use_agreement: }, status: :created
    end

    def render_error(message)
      render json: { error: message }, status: :unprocessable_entity
    end
  end
end
