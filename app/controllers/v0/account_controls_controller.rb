# frozen_string_literal: true

module V0
  class AccountControlsController < SignIn::ServiceAccountApplicationController
    service_tag 'identity'
    VALID_CSP_TYPES = %w[logingov idme dslogon mhv].freeze

    def credential_index
      if @service_account_access_token.user_attributes['icn'].blank?
        raise SignIn::Errors::MissingParamsError.new message: 'icn is not defined'
      end

      serialized_user_verifications = serialize_user_verifications(user_verifications: fetch_verifications_by_icn)
      Rails.logger.info('[V0::AccountControlsController] credential_index',
                        { icn: params[:icn], requested_by: @service_account_access_token.user_identifier })
      render json: { data: serialized_user_verifications }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'UserAccount not found.' }, status: :not_found
    rescue SignIn::Errors::MissingParamsError => e
      render json: { error: e.message }, status: :bad_request
    end

    def credential_lock
      validate_credential_params

      user_attributes = @service_account_access_token.user_attributes
      user_verification = UserVerification.find_by_type!(user_attributes['type'], user_attributes['credential_id'])
      user_verification.lock!
      Rails.logger.info('[V0::AccountControlsController] credential_lock', lock_log_info(user_verification:))
      render json: { data: serialize_user_verification(user_verification:) }
    rescue ActiveRecord::RecordInvalid
      Rails.logger.info('[V0::AccountControlsController] credential_lock failed', lock_log_info(user_verification:))
      render json: { error: 'UserAccount credential lock failed.' }, status: :internal_server_error
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'UserAccount credential record not found.' }, status: :not_found
    rescue SignIn::Errors::MissingParamsError, SignIn::Errors::MalformedParamsError => e
      render json: { error: e.message }, status: :bad_request
    end

    def credential_unlock
      validate_credential_params

      user_attributes = @service_account_access_token.user_attributes
      user_verification = UserVerification.find_by_type!(user_attributes['type'], user_attributes['credential_id'])
      user_verification.unlock!
      Rails.logger.info('[V0::AccountControlsController] credential_unlock', lock_log_info(user_verification:))
      render json: { data: serialize_user_verification(user_verification:) }
    rescue ActiveRecord::RecordInvalid
      Rails.logger.info('[V0::AccountControlsController] credential_unlock failed', lock_log_info(user_verification:))
      render json: { error: 'UserAccount credential unlock failed.' }, status: :internal_server_error
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'UserAccount credential record not found.' }, status: :not_found
    rescue SignIn::Errors::MissingParamsError, SignIn::Errors::MalformedParamsError => e
      render json: { error: e.message }, status: :bad_request
    end

    private

    def validate_credential_params
      user_attributes = @service_account_access_token.user_attributes

      if user_attributes['credential_id'].blank?
        raise SignIn::Errors::MissingParamsError.new message: 'credential_id is not defined'
      end
      raise SignIn::Errors::MissingParamsError.new message: 'type is not defined' if user_attributes['type'].blank?

      unless VALID_CSP_TYPES.include?(user_attributes['type'])
        raise SignIn::Errors::MalformedParamsError.new message: 'type is malformed'
      end
    end

    def fetch_verifications_by_icn
      user_account = UserAccount.find_by!(icn: @service_account_access_token.user_attributes['icn'])
      user_account.user_verifications
    end

    def serialize_user_verifications(user_verifications:)
      user_verifications.map { |user_verification| serialize_user_verification(user_verification:) }
    end

    def serialize_user_verification(user_verification:)
      UserVerificationSerializer.new(user_verification:).perform
    end

    def lock_log_info(user_verification:)
      serialize_user_verification(user_verification:).merge(requested_by: @service_account_access_token.user_identifier)
    end
  end
end
