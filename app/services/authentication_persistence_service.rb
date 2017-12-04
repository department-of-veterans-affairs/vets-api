# frozen_string_literal: true

class AuthenticationPersistenceService
  def initialize(saml_attributes)
    @saml_attributes = saml_attributes
  end

  attr_reader :new_session, :new_user, :new_user_identity, :saml_attributes

  def existing_user
    @existing_user ||= User.find(saml_attributes.user_attributes.uuid)
  end

  def self.extend!(session, user)
    session.expire(Session.redis_namespace_ttl)
    user&.expire(User.redis_namespace_ttl)
    user&.identity&.expire(UserIdentity.redis_namespace_ttl)
  end

  def persist_authentication!
    if existing_user.present?
      expire_existing!
    else
      @new_user_identity = UserIdentity.new(saml_attributes.to_hash)
      @new_user = init_new_user(new_user_identity)
      @new_session = Session.new(uuid: new_user.uuid)
      @new_session.save && @new_user.save && @new_user_identity.save
    end
  end

  def changing_multifactor?
    saml_attributes.changing_multifactor?
  end

  private

  def expire_existing!
    existing_user&.identity&.destroy
    existing_user.destroy
  end

  def init_new_user(user_identity)
    # Eventually it will be this
    # new_user = User.new(uuid: user_identity.uuid)
    new_user = User.new(user_identity.attributes)
    if changing_multifactor?
      new_user.mhv_last_signed_in = existing_user.last_signed_in
      new_user.last_signed_in = existing_user.last_signed_in
    else
      new_user.last_signed_in = Time.current.utc
    end
    new_user
  end
end
