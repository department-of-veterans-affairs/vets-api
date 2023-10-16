# frozen_string_literal: true

module V0
  class AccountControlsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    skip_before_action :authenticate, :verify_authenticity_token
    before_action :authenticate_service_account, :validate_account_control_params

    VALID_CSP_TYPES = %w[logingov idme dslogon mhv].freeze

    def csp_lock
      user_verification.update!(locked: true)

      Rails.logger.info('UserAccount CSP Lock', serialized_response)
      render json: { data: serialized_response }
    end

    def csp_unlock
      user_verification.update!(locked: false)

      Rails.logger.info('UserAccount CSP Unlock', serialized_response)
      render json: { data: serialized_response }
    end

    private

    def validate_account_control_params
      raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?
      raise Common::Exceptions::InvalidFieldValue.new('type', type) unless VALID_CSP_TYPES.include?(type)
      raise Common::Exceptions::ParameterMissing, 'csp_uuid' if params[:icn].blank? && params[:csp_uuid].blank?
    end

    def user_verification
      @user_verification ||= fetch_user_verification
    end

    def fetch_user_verification
      csp_uuid.presence ? UserVerification.find_by!("#{type}_uuid" => csp_uuid) : fetch_verification_by_icn
    end

    def fetch_verification_by_icn
      user_verifications = UserVerification.where(user_account_id: account.id)
      raise ActiveRecord::RecordNotFound unless user_verifications.exists?

      user_verifications.where.not("#{type}_uuid": nil).first
    end

    def account
      @account ||= fetch_user_account
    end

    def fetch_user_account
      icn.presence ? UserAccount.find_by!(icn:) : UserAccount.find(user_verification.user_account_id)
    end

    def type
      @type ||= params[:type]
    end

    def csp_uuid
      @csp_uuid ||= params[:csp_uuid]
    end

    def icn
      @icn ||= params[:icn]
    end

    def serialized_response
      @serialized_response ||= {
        csp_uuid: user_verification.send("#{type}_uuid"),
        type:,
        icn: account.icn,
        locked: user_verification.reload.locked,
        updated_by: @service_account_access_token.user_identifier
      }.compact
    end

    def not_found
      render json: { error: "User record not found. ICN:#{icn} #{type}_uuid:#{csp_uuid}" }, status: :not_found
    end
  end
end
