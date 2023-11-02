# frozen_string_literal: true

module V0
  class TermsOfUseAgreementsController < ApplicationController
    skip_before_action :authenticate

    before_action :terms_authenticate

    def latest
      terms_of_use_agreement = get_terms_of_use_agreements_for_version(params[:version]).last
      render_success(terms_of_use_agreement, :ok)
    end

    def accept
      terms_of_use_agreement = TermsOfUse::Acceptor.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      recache_user
      render_success(terms_of_use_agreement, :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.message)
    end

    def decline
      terms_of_use_agreement = TermsOfUse::Decliner.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      recache_user
      render_success(terms_of_use_agreement, :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(e.message)
    end

    private

    def recache_user
      current_user.needs_accepted_terms_of_use = current_user.user_account&.needs_accepted_terms_of_use?
      current_user.save
    end

    def get_terms_of_use_agreements_for_version(version)
      current_user.user_account.terms_of_use_agreements.where(agreement_version: version)
    end

    def authenticate_one_time_terms_code
      terms_code_container = SignIn::TermsCodeContainer.find(params[:terms_code])
      @current_user = User.find(terms_code_container.user_uuid)
    ensure
      terms_code_container&.destroy
    end

    def terms_authenticate
      params[:terms_code].present? ? authenticate_one_time_terms_code : load_user(skip_terms_check: true)

      raise Common::Exceptions::Unauthorized unless @current_user
    end

    def render_success(terms_of_use_agreement, status)
      render json: { terms_of_use_agreement: }, status:
    end

    def render_error(message)
      render json: { error: message }, status: :unprocessable_entity
    end
  end
end
