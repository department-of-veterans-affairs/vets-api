# frozen_string_literal: true

require 'inherited_proofing/mhv/inherited_proofing_verifier'
require 'inherited_proofing/logingov/service'
require 'inherited_proofing/jwt_decoder'
require 'inherited_proofing/user_attributes_encryptor'
require 'inherited_proofing/user_attributes_fetcher'
require 'inherited_proofing/errors'

class InheritedProofingController < ApplicationController
  skip_before_action :verify_authenticity_token, :authenticate, only: [:user_attributes]
  before_action :authenticate_auth_code_access_token, only: [:user_attributes]

  BEARER_PATTERN = /^Bearer /

  def auth
    auth_code = InheritedProofing::MHV::InheritedProofingVerifier.new(@current_user).perform

    raise unless auth_code

    render body: logingov_inherited_proofing_service.render_auth(auth_code:),
           content_type: 'text/html'
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  def user_attributes
    user_attributes = InheritedProofing::UserAttributesFetcher.new(auth_code: @auth_code).perform
    encrypted_attributes = InheritedProofing::UserAttributesEncryptor.new(user_attributes:).perform
    render json: { data: encrypted_attributes }
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  def callback
    validate_auth_code(params[:auth_code].presence)
    save_inherited_proofing_verification
    reset_session
    redirect_to controller: 'v1/sessions', action: :new, type: SAML::User::LOGINGOV_CSID
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def auth_code_bearer_token
    header = request.authorization
    access_token_jwt = header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
    InheritedProofing::JwtDecoder.new(access_token_jwt:).perform
  end

  def authenticate_auth_code_access_token
    access_token = auth_code_bearer_token
    @auth_code = access_token.inherited_proofing_auth
  rescue => e
    render json: { errors: e }, status: :unauthorized
  end

  def save_inherited_proofing_verification
    if InheritedProofVerifiedUserAccount.find_by(user_account: @current_user.user_account)
      raise InheritedProofing::Errors::PreviouslyVerifiedError
    end

    InheritedProofVerifiedUserAccount.new(user_account: @current_user.user_account).save!
  end

  def validate_auth_code(auth_code)
    raise InheritedProofing::Errors::AuthCodeMissingError unless auth_code

    audit_data = inherited_proofing_audit_data(auth_code)
    raise InheritedProofing::Errors::AuthCodeInvalidError unless audit_data
    raise InheritedProofing::Errors::InvalidUserError unless audit_data.user_uuid == @current_user.uuid
    raise InheritedProofing::Errors::InvalidCSPError unless
      audit_data.legacy_csp == @current_user.identity_sign_in[:service_name]
  ensure
    audit_data&.destroy
  end

  def inherited_proofing_audit_data(auth_code)
    @audit_data ||= InheritedProofing::AuditData.find(auth_code)
  end

  def logingov_inherited_proofing_service
    @logingov_inherited_proofing_service ||= InheritedProofing::Logingov::Service.new
  end
end
