# frozen_string_literal: true

require 'terms_of_use/exceptions'

module V0
  class TermsOfUseAgreementsController < ApplicationController
    service_tag 'terms-of-use'

    skip_before_action :verify_authenticity_token, only: [:update_provisioning]
    skip_before_action :authenticate
    before_action :terms_authenticate

    PROVISION_POLL_TIMEOUT_DURATION = 10
    PROVISION_POLL_SLEEP_DURATION = 2

    def latest
      terms_of_use_agreement = get_terms_of_use_agreements_for_version(params[:version]).last
      render_success(context: 'latest', body: { terms_of_use_agreement: })
    end

    def accept
      terms_of_use_agreement = TermsOfUse::Acceptor.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      recache_user
      render_success(context: 'accept', body: { terms_of_use_agreement: }, status: :created)
    rescue TermsOfUse::Errors::AcceptorError => e
      render_error(context: 'accept', message: e.message)
    end

    def accept_and_provision
      terms_of_use_agreement = TermsOfUse::Acceptor.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      recache_user
      update_provisioning
    rescue TermsOfUse::Errors::AcceptorError => e
      render_error(context: 'accept_and_provision', message: e.message)
    end

    def decline
      terms_of_use_agreement = TermsOfUse::Decliner.new(user_account: current_user.user_account,
                                                        common_name: current_user.common_name,
                                                        version: params[:version]).perform!
      recache_user
      render_success(context: 'decline', body: { terms_of_use_agreement: }, status: :created)
    rescue TermsOfUse::Errors::DeclinerError => e
      render_error(context: 'decline', message: e.message)
    end

    def update_provisioning
      if ActiveRecord::Type::Boolean.new.cast(params[:poll])
        poll_provisioning
      elsif provisioner.perform
        create_cerner_cookie
        render_success(context: 'update_provisioning', body: { provisioned: true }, status: :ok)
      else
        render_error(context: 'update_provisioning', message: 'Failed to provision', status: :unprocessable_entity)
      end
    rescue TermsOfUse::Errors::ProvisionerError => e
      render_error(context: 'update_provisioning', message: "Failed to provision. #{e.message}")
    end

    private

    def poll_provisioning
      Timeout.timeout(PROVISION_POLL_TIMEOUT_DURATION) do
        loop do
          if false
            create_cerner_cookie
            render_success(context: 'update_provisioning', body: { provisioned: true }, status: :ok)
            break
          end

          sleep PROVISION_POLL_SLEEP_DURATION
        end
      end
    rescue Timeout::Error
      render_error(context: 'update_provisioning', message: 'Failed to provision. Poll timeout',
                   status: :request_timeout)
    end

    def provisioner
      @provisioner ||= TermsOfUse::Provisioner.new(
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

    def render_success(context:, body:, status: :ok)
      Rails.logger.info("[TermsOfUseAgreementsController] #{context} success", { icn: current_user.icn })
      render json: body, status:
    end

    def render_error(context:, message:, status: :unprocessable_entity)
      Rails.logger.error("[TermsOfUseAgreementsController] #{context} error: #{message}", { icn: current_user.icn })
      render json: { error: message }, status:
    end
  end
end
