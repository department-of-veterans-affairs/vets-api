# frozen_string_literal: true

VAProfilePolicy = Struct.new(:user, :va_profile) do
  def access?
    user.edipi.present?
  end

  def access_to_v2?
    if Flipper.enabled?(:va_v3_contact_information_service, user)
      # user vet360_id is no longer needed for Contact Information Api V2
      user.vet360_id.present? || user.idme_uuid.present? || user.logingov_uuid.present?
    else
      user.vet360_id.present?
    end
  end
end
