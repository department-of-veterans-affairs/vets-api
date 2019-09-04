# frozen_string_literal: true

module VAOS
  class AppointmentService < Service
    def get_appointments(user)
      start_date = Time.now.utc.beginning_of_day + 7.hours
      end_date = start_date + 4.months + 1.hours
      url = "/appointments/v1/patients/#{user.icn}/appointments?startDate=#{format_date(start_date)}&endDate=#{format_date(end_date)}&useCache=false&pageSize=0"
      perform(:get, url, {})
    end

    private

    def format_date(date)
      date.strftime("%Y-%m-%dT%TZ")
    end
  end
end
