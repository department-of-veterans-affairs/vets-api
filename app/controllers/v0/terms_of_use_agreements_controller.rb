# frozen_string_literal: true

require 'terms_of_use/exceptions'

module V0
  class TermsOfUseAgreementsController < ApplicationController
    service_tag 'terms-of-use'

    skip_before_action :verify_authenticity_token, only: [:update_provisioning]
    skip_before_action :authenticate
    before_action :terms_authenticate

    def latest
      terms_of_use_agreement = find_latest_agreement_by_version(params[:version])
      render_success(action: 'latest', body: { terms_of_use_agreement: })
    end

    def accept
      terms_of_use_agreement = acceptor.perform!

      recache_user
      render_success(action: 'accept', body: { terms_of_use_agreement: }, status: :created)
    rescue TermsOfUse::Errors::AcceptorError => e
      render_error(action: 'accept', message: e.message)
    end

    def accept_and_provision
      terms_of_use_agreement = acceptor(async: false).perform!

      if terms_of_use_agreement.accepted? && provisioner.perform
        create_cerner_cookie
        recache_user
        render_success(action: 'accept_and_provision', body: { terms_of_use_agreement:, provisioned: true },
                       status: :created)
      else
        render_error(action: 'accept_and_provision', message: 'Failed to accept and provision')
      end
    rescue TermsOfUse::Errors::AcceptorError => e
      render_error(action: 'accept_and_provision', message: e.message)
    end

    def decline
      terms_of_use_agreement = decliner.perform!

      recache_user
      render_success(action: 'decline', body: { terms_of_use_agreement: }, status: :created)
    rescue TermsOfUse::Errors::DeclinerError => e
      render_error(action: 'decline', message: e.message)
    end

    def update_provisioning
      if provisioner.perform
        create_cerner_cookie
        render_success(action: 'update_provisioning', body: { provisioned: true }, status: :ok)
      else
        render_error(action: 'update_provisioning', message: 'Failed to provision')
      end
    rescue TermsOfUse::Errors::ProvisionerError => e
      render_error(action: 'update_provisioning', message: e.message)
    end

    private

    def acceptor(async: true)
      TermsOfUse::Acceptor.new(
        user_account: current_user.user_account,
        common_name: current_user.common_name,
        version: params[:version],
        async:
      )
    end

    def decliner
      TermsOfUse::Decliner.new(
        user_account: current_user.user_account,
        common_name: current_user.common_name,
        version: params[:version]
      )
    end

    def provisioner
      TermsOfUse::Provisioner.new(
        icn: current_user.icn,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        mpi_gcids: current_user.mpi_gcids
      )
    end

    def recache_user
      current_user.needs_accepted_terms_of_use = current_user.user_account&.needs_accepted_terms_of_use?
      current_user.save
    end

    def create_cerner_cookie
      cookies[TermsOfUse::Constants::PROVISIONER_COOKIE_NAME] = {
        value: TermsOfUse::Constants::PROVISIONER_COOKIE_VALUE,
        expires: TermsOfUse::Constants::PROVISIONER_COOKIE_EXPIRATION.from_now,
        path: TermsOfUse::Constants::PROVISIONER_COOKIE_PATH,
        domain: TermsOfUse::Constants::PROVISIONER_COOKIE_DOMAIN
      }
    end

    def find_latest_agreement_by_version(version)
      current_user.user_account.terms_of_use_agreements.where(agreement_version: version).last
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

    def render_success(action:, body:, status: :ok)
      Rails.logger.info("[TermsOfUseAgreementsController] #{action} success", { icn: current_user.icn })
      render json: body, status:
    end

    def render_error(action:, message:, status: :unprocessable_entity)
      Rails.logger.error("[TermsOfUseAgreementsController] #{action} error: #{message}", { icn: current_user.icn })
      render json: { error: message }, status:
    end
  end
end
