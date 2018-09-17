# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  def access?
    if user.edipi.present? && user.ssn.present? && user.participant_id.present?
      StatsD.increment('api.evss.policy.success') if user.loa3?
      true
    else
      StatsD.increment('api.evss.policy.failure') if user.loa3?
      false
    end
  end
end
