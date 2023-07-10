# frozen_string_literal: true

MebPolicy = Struct.new(:user, :my_education_benefits) do
  def access?
    accessible = user.icn.present? && user.ssn.present? && user.loa3?
    increment_statsd(accessible)
    accessible
  end

  def increment_statsd(accessible)
    if accessible
      StatsD.increment('api.my_education_benefits.policy.success')
    else
      StatsD.increment('api.my_education_benefits.policy.failure')
    end
  end
end
