# frozen_string_literal: true

Vet360Policy = Struct.new(:user, :vet360) do
  def access?
    user.vet360_id.present?
  end

  def military_access?
    user.edipi.present?
  end

  def profile_access?
    if Flipper.enabled?(:remove_pciu, user)
      user.icn.present?
    else
      user.vet360_id.present?
    end
  end
end
