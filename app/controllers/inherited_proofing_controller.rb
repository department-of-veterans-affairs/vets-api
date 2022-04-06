# frozen_string_literal: true

require 'inherited_proofing/mhv/inherited_proofing_verifier'
require 'inherited_proofing/logingov/service'
require 'inherited_proofing/jwt_decoder'
require 'inherited_proofing/user_attributes_encryptor'
require 'inherited_proofing/user_attributes_fetcher'

class InheritedProofingController < ApplicationController
  skip_before_action :verify_authenticity_token, :authenticate, only: [:user_attributes]
  before_action :authenticate_access_token, only: [:user_attributes]

  BEARER_PATTERN = /^Bearer /.freeze

  def auth
    auth_code = InheritedProofing::MHV::InheritedProofingVerifier.new(@current_user).perform

    raise unless auth_code

    render body: logingov_inherited_proofing_service.render_auth(auth_code: auth_code),
           content_type: 'text/html'
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  def user_attributes
    user_attributes = InheritedProofing::UserAttributesFetcher.new(auth_code: @auth_code).perform
    encrypted_attributes = InheritedProofing::UserAttributesEncryptor.new(user_attributes: user_attributes).perform
    render json: { data: encrypted_attributes }
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def bearer_token
    header = request.authorization
    access_token_jwt = header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
    InheritedProofing::JwtDecoder.new(access_token_jwt: access_token_jwt).perform
  end

  def authenticate_access_token
    access_token = bearer_token
    @auth_code = access_token.inherited_proofing_auth
  rescue => e
    render json: { errors: e }, status: :unauthorized
  end

  def logingov_inherited_proofing_service
    @logingov_inherited_proofing_service ||= InheritedProofing::Logingov::Service.new
  end
end
