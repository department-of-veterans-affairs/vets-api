# frozen_string_literal: true

module VAOS
  class AppointmentService < Common::Client::Base
    configuration VAOS::Configuration

    def get_appointments(user)
      start_date = (Time.now.utc.beginning_of_day + 7.hours).strftime('%Y-%m-%dT%TZ')
      end_date = (Time.now.utc.beginning_of_day + 8.hours + 4.months).strftime('%Y-%m-%dT%TZ')
      url = "/appointments/v1/patients/#{user.icn}/appointments"\
              "?startDate=#{start_date}&endDate=#{end_date}&useCache=false&pageSize=0"
      response = perform(:get, url, {})
      response.body.deep_symbolize_keys![:data].map { |appointment| VAOS::Appointment.new(appointment) }
    end

    private

    def format_date(date)
      date
    end
  end
end
