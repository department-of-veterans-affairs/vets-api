# frozen_string_literal: true

BGSPolicy = Struct.new(:user, :bgs) do
  def access?
    accessible = user.icn.present? && user.ssn.present? && user.participant_id.present?
    increment_statsd_for_loa_user(accessible)
    accessible
  end

  def increment_statsd_for_loa_user(accessible)
    return unless user.loa3?
    if accessible
      StatsD.increment('api.bgs.policy.success')
    else
      StatsD.increment('api.bgs.policy.failure')
    end
  end
end
