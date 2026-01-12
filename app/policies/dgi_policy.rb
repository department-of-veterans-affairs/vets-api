# frozen_string_literal: true

DGIPolicy = Struct.new(:user, :dgi) do
  def access?
    accessible = user.icn.present? && user.ssn.present? && user.loa3?
    increment_statsd(accessible)
    accessible
  end

  def increment_statsd(accessible)
    if accessible
      StatsD.increment('api.dgi.policy.success')
    else
      StatsD.increment('api.dgi.policy.failure')
    end
  end
end
