# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    user.edipi.present? && user.ssn.present? && user.participant_id.present?
  end

  def access_common_client?
    user.beta_enabled?(user.uuid, EVSSClaimService::EVSS_COMMON_CLIENT_KEY)
  end
end
