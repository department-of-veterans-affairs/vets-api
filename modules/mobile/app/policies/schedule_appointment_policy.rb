# frozen_string_literal: true

ScheduleAppointmentPolicy = Struct.new(:user, :schedule_appointment) do
  def access?
    accessible = user.loa3? && user.va_treatment_facility_ids.length.positive?
    increment_statsd(accessible)
    accessible
  end

  def increment_statsd(accessible)
    if accessible
      StatsD.increment('mobile.schedule_appointment.policy.success')
    else
      StatsD.increment('mobile.schedule_appointment.policy.failure')
    end
  end
end
