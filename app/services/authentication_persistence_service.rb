# frozen_string_literal: true

class AuthenticationPersistenceService
  def initialize(saml_response)
    raise 'SAML Response is required' if saml_response.nil?
    @saml_response = saml_response
    @saml_attributes = SAML::User.new(@saml_response)
  end

  attr_reader :new_session, :new_user, :new_user_identity, :saml_attributes

  def existing_user
    @existing_user ||= User.find(saml_attributes.user_attributes.uuid)
  end

  def self.extend!(session, user)
    session.expire(Session.redis_namespace_ttl)
    user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    user&.expire(User.redis_namespace_ttl)
  end

  def persist_authentication!
    return false unless @saml_response.is_valid?
    @new_user_identity = UserIdentity.new(saml_attributes.to_hash)
    @new_user = init_new_user(new_user_identity, existing_user, saml_attributes.changing_multifactor?)
    @new_session = Session.new(uuid: new_user.uuid)

    if existing_user.present?
      existing_user&.identity&.destroy
      existing_user.destroy
    end

    @new_session.save && @new_user.save && @new_user_identity.save
  end

  private

  def expire_existing!
    existing_user&.identity&.destroy
    existing_user.destroy
    @existing_user = nil
  end

  def init_new_user(user_identity, existing_user = nil, multifactor_change = false)
    new_user = User.new(user_identity.attributes)
    if multifactor_change
      new_user.mhv_last_signed_in = existing_user.last_signed_in
      new_user.last_signed_in = existing_user.last_signed_in
    else
      new_user.last_signed_in = Time.current.utc
    end
    new_user
  end
end
