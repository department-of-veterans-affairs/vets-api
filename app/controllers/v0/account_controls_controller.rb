# frozen_string_literal: true

module V0
  class AccountControlsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    skip_before_action :authenticate
    before_action :authenticate_service_account, :validate_account_control_params

    def csp_lock
      update_user_verifications(locked: true)

      Rails.logger.info('UserAccount CSP Lock', serialized_response)
      render json: { data: serialized_response }
    end

    def csp_unlock
      update_user_verifications(locked: false)

      Rails.logger.info('UserAccount CSP Unlock', serialized_response)
      render json: { data: serialized_response }
    end

    private

    def update_user_verifications(locked:)
      if type == 'logingov'
        user_verification&.update!(locked:)
      else
        UserVerification.where(user_account_id: account.id, logingov_uuid: nil).each do |idme_backed_verification|
          idme_backed_verification.update!(locked:)
        end
      end
    end

    def validate_account_control_params
      raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?
      raise Common::Exceptions::InvalidFieldValue.new('type', type) unless %w[idme logingov].include?(type)
      raise Common::Exceptions::ParameterMissing, 'csp_uuid' if params[:icn].blank? && params[:csp_uuid].blank?
    end

    def user_verification
      @user_verification ||= fetch_user_verification
    end

    def fetch_user_verification
      icn.presence ? fetch_verification_by_icn : UserVerification.find_by!("#{type}_uuid" => csp_uuid)
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
      raise StandardError, "User record not found. ICN:#{icn} #{type}_uuid:#{csp_uuid}"
    end
  end
end
