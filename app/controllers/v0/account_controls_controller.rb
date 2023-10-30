# frozen_string_literal: true

module V0
  class AccountControlsController < ApplicationController
    skip_before_action :authenticate, :verify_authenticity_token
    before_action :authenticate_service_account

    VALID_CSP_TYPES = %w[logingov idme dslogon mhv].freeze

    def credential_index
      raise Common::Exceptions::ParameterMissing, 'icn' if params[:icn].blank?

      serialized_user_verifications = serialize_user_verifications(user_verifications: fetch_verifications_by_icn)
      Rails.logger.info('[V0::AccountControlsController] credential_index',
                        { icn: params[:icn], requested_by: @service_account_access_token.user_identifier })
      render json: { data: serialized_user_verifications }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'UserAccount not found.' }, status: :not_found
    rescue Common::Exceptions::ParameterMissing => e
      render json: { error: e.errors.first.detail }, status: :bad_request
    end

    def credential_lock
      validate_credential_params

      user_verification.update!(locked: true)
      Rails.logger.info('[V0::AccountControlsController] credential_lock', lock_log_info)
      render json: { data: serialized_user_verification }
    rescue ActiveRecord::RecordInvalid
      Rails.logger.info('[V0::AccountControlsController] credential_lock failed',
                        lock_log_info)
      render json: { error: 'UserAccount credential lock failed.' }, status: :internal_server_error
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'UserAccount credential record not found.' }, status: :not_found
    rescue Common::Exceptions::ParameterMissing, Common::Exceptions::InvalidFieldValue => e
      render json: { error: e.errors.first.detail }, status: :bad_request
    end

    def credential_unlock
      validate_credential_params

      user_verification.update!(locked: false)
      Rails.logger.info('[V0::AccountControlsController] credential_unlock', lock_log_info)
      render json: { data: serialized_user_verification }
    rescue ActiveRecord::RecordInvalid
      Rails.logger.info('[V0::AccountControlsController] credential_unlock failed', lock_log_info)
      render json: { error: 'UserAccount credential unlock failed.' }, status: :internal_server_error
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'UserAccount credential record not found.' }, status: :not_found
    rescue Common::Exceptions::ParameterMissing, Common::Exceptions::InvalidFieldValue => e
      render json: { error: e.errors.first.detail }, status: :bad_request
    end

    private

    def validate_credential_params
      raise Common::Exceptions::ParameterMissing, 'credential_id' if params[:credential_id].blank?
      raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?

      unless VALID_CSP_TYPES.include?(params[:type])
        raise Common::Exceptions::InvalidFieldValue.new('type', params[:type])
      end
    end

    def user_verification
      @user_verification ||= UserVerification.find_by_type(params[:type], params[:credential_id])
    end

    def fetch_verifications_by_icn
      user_account = UserAccount.find_by!(icn: params[:icn])
      user_account.user_verifications
    end

    def serialize_user_verifications(user_verifications:)
      user_verifications.map { |user_verification| UserVerificationSerializer.new(user_verification:).perform }
    end

    def serialized_user_verification
      @serialize_user_verification ||= UserVerificationSerializer.new(user_verification:).perform
    end

    def lock_log_info
      serialized_user_verification.merge({ requested_by: @service_account_access_token.user_identifier })
    end
  end
end
