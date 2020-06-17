# frozen_string_literal: true

BGSPolicy = Struct.new(:user, :bgs) do
  def access?
    if user.icn.present? && user.ssn.present? && user.participant_id.present?
      StatsD.increment('api.bgs.policy.success') if user.loa3?
      true
    else
      StatsD.increment('api.bgs.policy.failure') if user.loa3?
      false
    end
  end
end
