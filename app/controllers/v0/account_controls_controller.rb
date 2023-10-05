# frozen_string_literal: true

module V0
  class AccountControlsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    skip_before_action :authenticate, :verify_authenticity_token
    before_action :authenticate_service_account, :validate_account_control_params

    def csp_lock
      user_verification&.update!(locked: true)

      Rails.logger.info('UserAccount CSP Lock', serialized_response)
      render json: { data: serialized_response }
    end

    def csp_unlock
      user_verification&.update!(locked: false)

      Rails.logger.info('UserAccount CSP Unlock', serialized_response)
      render json: { data: serialized_response }
    end

    private

    def validate_account_control_params
      raise Common::Exceptions::ParameterMissing, 'type', 'CSP type is required' if params[:type].blank?
      raise Common::Exceptions::ParameterMissing, 'type', "#{type} is not a valid CSP type" unless %w[idme
                                                                                                      logingov].include?(type)

      if params[:icn].blank? && params[:csp_uuid].blank?
        raise Common::Exceptions::ParameterMissing, 'csp_uuid',
              'CSP UUID or ICN is required'
      end
    end

    def user_verification
      @user_verification ||= fetch_user_verification
    end

    def fetch_user_verification
      csp_uuid ? UserVerification.find_by!("#{type}_uuid" => csp_uuid) : fetch_verification_by_icn
    end

    def fetch_verification_by_icn
      @account = UserAccount.find_by!(icn:)
      verifications = UserVerification.where(user_account_id: account.id)
      raise ActiveRecord::RecordNotFound unless verifications.exists?

      verifications.where.not("#{type}_uuid": nil).first
    end

    def serialized_response
      @serialized_response ||= {
        csp_uuid: user_verification.send("#{type}_uuid"),
        type:,
        icn: @account&.icn || UserAccount.find(user_verification.user_account_id).icn,
        locked: user_verification.locked,
        updated_by: @service_account_access_token.user_identifier
      }.compact
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

    def not_found
      render json: { error: 'User record not found' }, status: :not_found
    end
  end
end
