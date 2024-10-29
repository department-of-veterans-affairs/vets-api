# frozen_string_literal: true

Vet360Policy = Struct.new(:user, :vet360) do
  def access?
    if Flipper.enabled?(:va_v3_contact_information_service, user)
      # user vet360_id is no longer needed for Contact Information Api V2
      user.vet360_id.present? || user.idme_uuid.present? || user.logingov_uuid.present?
    else
      user.vet360_id.present?
    end
  end

  def military_access?
    user.edipi.present?
  end
end
