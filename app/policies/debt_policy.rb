# frozen_string_literal: true

DebtPolicy = Struct.new(:user, :debt) do
  def access?
    accessible = user.icn.present? && user.ssn.present? && user.loa3?

    increment_statsd(accessible)
    accessible
  end

  def increment_statsd(accessible)
    if accessible
      StatsD.increment('api.debt.policy.success')
    else
      StatsD.increment('api.debt.policy.failure')
    end
  end
end
