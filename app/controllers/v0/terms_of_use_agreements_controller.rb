# frozen_string_literal: true

module V0
  class TermsOfUseAgreementsController < ApplicationController
    def latest
      terms_of_use_agreement = get_terms_of_use_agreements_for_version(params[:version]).last
      render_success(terms_of_use_agreement, :ok)
    end

    def accept
      terms_of_use_agreement = TermsOfUse::Acceptor.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      render_success(terms_of_use_agreement, :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.message)
    end

    def decline
      terms_of_use_agreement = TermsOfUse::Decliner.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      render_success(terms_of_use_agreement, :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.message)
    end

    private

    def get_terms_of_use_agreements_for_version(version)
      current_user.user_account.terms_of_use_agreements.where(agreement_version: version)
    end

    def render_success(terms_of_use_agreement, status)
      render json: { terms_of_use_agreement: }, status:
    end

    def render_error(message)
      render json: { error: message }, status: :unprocessable_entity
    end
  end
end
