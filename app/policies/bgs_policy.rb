# frozen_string_literal: true

BGSPolicy = Struct.new(:user, :bgs) do
  def access?
    accessible = user.icn.present? && user.ssn.present? && user.participant_id.present?
    increment_statsd_for_loa_user(accessible) if user.loa3?
    accessible
  end

  def increment_statsd_for_loa_user(accessible)
    if accessible
      StatsD.increment('api.bgs.policy.success')
    else
      StatsD.increment('api.bgs.policy.failure')
    end
  end
end
