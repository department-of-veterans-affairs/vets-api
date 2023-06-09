# frozen_string_literal: true

DemographicsPolicy = Struct.new(:user, :gender_identity) do
  def access?
    user&.idme_uuid.present? || user&.logingov_uuid.present?
  end

  def access_update?
    user&.idme_uuid.present? || user&.logingov_uuid.present?
  end
end
