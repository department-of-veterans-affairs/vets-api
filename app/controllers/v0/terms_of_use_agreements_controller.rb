# frozen_string_literal: true

require 'terms_of_use/exceptions'

module V0
  class TermsOfUseAgreementsController < ApplicationController
    service_tag 'terms-of-use'
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
    rescue TermsOfUse::Errors::AcceptorError => e
      render_error(e.message)
    end

    def decline
      terms_of_use_agreement = TermsOfUse::Decliner.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      recache_user
      render_success(terms_of_use_agreement, :created)
    rescue TermsOfUse::Errors::DeclinerError => e
      render_error(e.message)
    end

    def update_provisioning
      provisioner = TermsOfUse::Provisioner.new(icn: current_user.icn,
                                                first_name: current_user.first_name,
                                                last_name: current_user.last_name,
                                                mpi_gcids: current_user.mpi_gcids)
      if provisioner.perform
        create_cerner_cookie
        render json: { provisioned: true }, status: :ok
      else
        render_error('Failed to provision')
      end
    rescue TermsOfUse::Errors::ProvisionerError => e
      render_error(e.message)
    end

    private

    def recache_user
      current_user.needs_accepted_terms_of_use = current_user.user_account&.needs_accepted_terms_of_use?
      current_user.save
    end

    def create_cerner_cookie
      cookies[TermsOfUse::Constants::PROVISIONER_COOKIE_NAME] = {
        value: TermsOfUse::Constants::PROVISIONER_COOKIE_VALUE,
        expires: TermsOfUse::Constants::PROVISIONER_COOKIE_EXPIRATION.from_now,
        path: TermsOfUse::Constants::PROVISIONER_COOKIE_PATH,
        domain: Settings.terms_of_use.provisioner_cookie_domain
      }
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
