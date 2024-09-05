# frozen_string_literal: true

require 'terms_of_use/exceptions'

module V0
  class TermsOfUseAgreementsController < ApplicationController
    service_tag 'terms-of-use'

    skip_before_action :verify_authenticity_token, only: [:update_provisioning]
    skip_before_action :authenticate
    before_action :terms_authenticate, except: [:current_status]

    def current_status
      agreement_status = find_terms_of_use_agreement_by_icn(params[:icn])
      render_success(action: 'current_status', body: { agreement_status: }, icn: params[:icn])
    end

    def latest
      terms_of_use_agreement = find_latest_agreement_by_version(params[:version])
      render_success(action: 'latest', body: { terms_of_use_agreement: })
    end

    def accept
      terms_of_use_agreement = acceptor.perform!
      recache_user unless terms_code_temporary_auth?
      render_success(action: 'accept', body: { terms_of_use_agreement: }, status: :created)
    rescue TermsOfUse::Errors::AcceptorError => e
      render_error(action: 'accept', message: e.message)
    end

    def accept_and_provision
      terms_of_use_agreement = acceptor(sync: true).perform!
      if terms_of_use_agreement.accepted?
        provisioner.perform
        create_cerner_cookie
        recache_user unless terms_code_temporary_auth?
        render_success(action: 'accept_and_provision', body: { terms_of_use_agreement:, provisioned: true },
                       status: :created)
      else
        render_error(action: 'accept_and_provision', message: 'Failed to accept and provision')
      end
    rescue TermsOfUse::Errors::AcceptorError, TermsOfUse::Errors::ProvisionerError => e
      render_error(action: 'accept_and_provision', message: e.message)
    end

    def decline
      terms_of_use_agreement = decliner.perform!
      recache_user unless terms_code_temporary_auth?
      render_success(action: 'decline', body: { terms_of_use_agreement: }, status: :created)
    rescue TermsOfUse::Errors::DeclinerError => e
      render_error(action: 'decline', message: e.message)
    end

    def update_provisioning
      provisioner.perform
      create_cerner_cookie
      render_success(action: 'update_provisioning', body: { provisioned: true }, status: :ok)
    rescue TermsOfUse::Errors::ProvisionerError => e
      render_error(action: 'update_provisioning', message: e.message)
    end

    private

    def acceptor(sync: false)
      TermsOfUse::Acceptor.new(user_account: @user_account, version: params[:version], sync:)
    end

    def decliner
      TermsOfUse::Decliner.new(user_account: @user_account, version: params[:version])
    end

    def provisioner
      TermsOfUse::Provisioner.new(icn: @user_account.icn)
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

    def find_terms_of_use_agreement_by_icn(icn)
      user_account = UserAccount.find_by(icn:)
      return unless user_account

      latest_terms_of_use_agreement = user_account.terms_of_use_agreements.current.last
      latest_terms_of_use_agreement&.response
    end

    def find_latest_agreement_by_version(version)
      @user_account.terms_of_use_agreements.where(agreement_version: version).last
    end

    def authenticate_one_time_terms_code
      terms_code_container = SignIn::TermsCodeContainer.find(params[:terms_code])
      return unless terms_code_container

      @user_account = UserAccount.find(terms_code_container.user_account_uuid)
    ensure
      terms_code_container&.destroy
    end

    def authenticate_current_user
      load_user(skip_terms_check: true)
      return unless current_user

      @user_account = current_user.user_account
    end

    def terms_code_temporary_auth?
      params[:terms_code].present?
    end

    def terms_authenticate
      terms_code_temporary_auth? ? authenticate_one_time_terms_code : authenticate_current_user

      raise Common::Exceptions::Unauthorized unless @user_account
    end

    def mpi_profile
      @mpi_profile ||= MPI::Service.new.find_profile_by_identifier(identifier: @user_account.icn,
                                                                   identifier_type: MPI::Constants::ICN)&.profile
    end

    def render_success(action:, body:, status: :ok, icn: @user_account.icn)
      Rails.logger.info("[TermsOfUseAgreementsController] #{action} success", { icn: })
      render json: body, status:
    end

    def render_error(action:, message:, status: :unprocessable_entity)
      Rails.logger.error("[TermsOfUseAgreementsController] #{action} error: #{message}", { icn: @user_account.icn })
      render json: { error: message }, status:
    end
  end
end
