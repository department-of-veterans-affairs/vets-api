# frozen_string_literal: true

class UserSessionForm
  include ActiveModel::Validations

  attr_reader :user, :session

  def initialize(saml_response)
    saml_attributes = SAML::User.new(saml_response)
    existing_user = User.find(saml_attributes.user_attributes.uuid)
    @user_identity = UserIdentity.new(saml_attributes.to_hash)
    @user = User.new(uuid: @user_identity.attributes[:uuid])
    @user.instance_variable_set(:@identity, @user_identity)
    if saml_attributes.changing_multifactor?
      @user.mhv_last_signed_in = existing_user.last_signed_in
      @user.last_signed_in = existing_user.last_signed_in
    else
      @user.last_signed_in = Time.current.utc
    end
    @session = Session.new(uuid: @user.uuid)
  end

  def valid?
    errors.add(:session, :invalid) unless session.valid?
    errors.add(:user, :invalid) unless user.valid?
    errors.add(:user_identity, :invalid) unless @user_identity.valid?
  end

  def save
    valid? && session.save && user.save && @user_identity.save
  end

  def persist
    if save
      [user, session]
    else
      [nil, nil]
    end
  end
end
