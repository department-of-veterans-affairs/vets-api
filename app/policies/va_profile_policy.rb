# frozen_string_literal: true

VAProfilePolicy = Struct.new(:user, :va_profile) do
  def access?
    user.edipi.present?
  end

  def access_to_v2?
    if Flipper.enabled?(:remove_pciu, user)
      user.icn.present?
    else
      user.vet360_id.present?
    end
  end
end
