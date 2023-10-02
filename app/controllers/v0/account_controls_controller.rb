# frozen_string_literal: true

module V0
  class AccountControlsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    skip_before_action :authenticate, :verify_authenticity_token
    before_action :authenticate_service_account, :validate_account_control_params

    def csp_lock
      user_verification&.update!("#{type}_lock" => true)

      render json: { user_verification: }
    end

    def csp_unlock
      user_verification&.update!("#{type}_lock" => false)

      render json: { user_verification: }
    end

    private

    def validate_account_control_params
      raise Common::Exceptions::ParameterMissing, 'type', "CSP type is required" if params[:type].blank?
      raise Common::Exceptions::ParameterMissing, 'type', "#{type} is not a valid CSP type" unless %w[idme logingov].include?(type)
      raise Common::Exceptions::ParameterMissing, 'csp_uuid', "CSP UUID or ICN is required" if params[:icn].blank? && params[:csp_uuid].blank?
    end

    def user_verification
      @user_verification ||= UserVerification.find_by("#{type}_uuid" => csp_uuid)
    end

    def fetch_csp_uuid
      return params[:csp_uuid] if params[:csp_uuid].presence

      account = Account.find_by(icn:)
      account&.send("#{type}_uuid")
    end

    def type
      @type ||= params[:type]
    end

    def csp_uuid
      @csp_uuid ||= fetch_csp_uuid
    end

    def icn
      @icn ||= params[:icn]
    end
  end
end
