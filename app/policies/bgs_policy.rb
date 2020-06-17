# frozen_string_literal: true

BGSPolicy = Struct.new(:user, :bgs) do
  def access?
    accessible = user.icn.present? && user.ssn.present? && user.participant_id.present?
    increment_statsd(accessible) if user.loa3?
    accessible
  end

  def increment_statsd(accessible)
    if accessible
      StatsD.increment('api.bgs.policy.success')
    else
      StatsD.increment('api.bgs.policy.failure')
    end
  end
end
