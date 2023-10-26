# frozen_string_literal: true

module V0
  class AccountControlsController < ApplicationController
    skip_before_action :authenticate, :verify_authenticity_token
    before_action :authenticate_service_account

    VALID_CSP_TYPES = %w[logingov idme dslogon mhv].freeze

    def csp_index
      raise Common::Exceptions::ParameterMissing, 'icn' if params[:icn].blank?

      serialized_user_verifications = serialize_user_verifications(user_verifications: fetch_verifications_by_icn)
      Rails.logger.info('UserAccount CSP Index', { icn: params[:icn],
                                                   requested_by: @service_account_access_token.user_identifier })
      render json: { data: serialized_user_verifications }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "User CSP Index not found. ICN:#{params[:icn]}" }, status: :not_found
    end

    def csp_lock
      validate_csp_params

      if user_verification.update(locked: true)
        Rails.logger.info('UserAccount CSP lock', serialized_lock_response)
        render json: { data: serialized_lock_response }
      else
        Rails.logger.info('UserAccount CSP lock failed', serialized_lock_response)
        render json: { error: "User CSP record lock failed. #{params[:type]}_uuid:#{params[:csp_uuid]}" },
               status: :internal_server_error
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: "User CSP record not found. #{params[:type]}_uuid:#{params[:csp_uuid]}" },
             status: :not_found
    end

    def csp_unlock
      validate_csp_params

      if user_verification.update(locked: false)
        Rails.logger.info('UserAccount CSP unlock', serialized_lock_response)
        render json: { data: serialized_lock_response }
      else
        Rails.logger.info('UserAccount CSP unlock failed', serialized_lock_response)
        render json: { error: "User CSP record unlock failed. #{params[:type]}_uuid:#{params[:csp_uuid]}" },
               status: :internal_server_error
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: "User CSP record not found. #{params[:type]}_uuid:#{params[:csp_uuid]}" },
             status: :not_found
    end

    private

    def validate_csp_params
      raise Common::Exceptions::ParameterMissing, 'csp_uuid' if params[:csp_uuid].blank?
      raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?

      unless VALID_CSP_TYPES.include?(params[:type])
        raise Common::Exceptions::InvalidFieldValue.new('type', params[:type])
      end
    end

    def user_verification
      @user_verification ||= UserVerification.find_by!("#{params[:type]}_uuid" => params[:csp_uuid])
    end

    def fetch_verifications_by_icn
      user_account = UserAccount.find_by!(icn: params[:icn])
      user_verifications = UserVerification.where(user_account_id: user_account.id)
      raise ActiveRecord::RecordNotFound unless user_verifications.exists?

      user_verifications
    end

    def parse_verification_values(user_verification:)
      csp_uuid = nil
      type = VALID_CSP_TYPES.filter do |csp_type|
        uuid = user_verification.send("#{csp_type}_uuid")
        csp_uuid = uuid if uuid.present?
        uuid.present?
      end

      [type.first, csp_uuid]
    end

    def serialize_user_verifications(user_verifications:)
      serialized_verifications = user_verifications.map do |user_verification|
        type, csp_uuid = parse_verification_values(user_verification:)
        { type:, csp_uuid:, locked: user_verification.locked }
      end
      {
        icn: params[:icn],
        csp_verifications: serialized_verifications
      }
    end

    def serialized_lock_response
      {
        type: params[:type],
        csp_uuid: params[:csp_uuid],
        locked: user_verification.reload.locked,
        requested_by: @service_account_access_token.user_identifier
      }
    end
  end
end
