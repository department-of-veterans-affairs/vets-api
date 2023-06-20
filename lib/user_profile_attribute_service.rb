# frozen_string_literal: true

class UserProfileAttributeService
  def initialize(user)
    @user = user
  end

  def cache_profile_attributes
    cache = UserProfileAttributes.create(attribute_serial)
    cache.uuid
  end

  private

  def attribute_serial
    {
      uuid: SecureRandom.uuid,
      icn: @user.icn,
      first_name: @user.first_name,
      last_name: @user.last_name,
      email: @user.email,
      ssn: @user.ssn
    }
  end
end
