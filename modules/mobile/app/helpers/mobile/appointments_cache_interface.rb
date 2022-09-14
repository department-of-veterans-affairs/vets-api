# frozen_string_literal: true

module Mobile
  class AppointmentsCacheInterface
    def initialize
      @now = DateTime.now.utc
    end

    def fetch_appointments(user:, start_date: nil, end_date: nil, fetch_cache: true)
      appointments = nil
      search_start_date = [start_date, latest_allowable_cache_start_date].compact.min
      search_end_date = [end_date, earliest_allowable_cache_end_date].compact.max

      if use_cache?(search_start_date, search_end_date, fetch_cache)
        appointments = Mobile::V0::Appointment.get_cached(user)
        if appointments
          Rails.logger.info('mobile appointments cache fetch', user_uuid: user.uuid)
          return appointments
        end
      end

      appointments = fetch_from_external_service(user, search_start_date, search_end_date)
      Mobile::V0::Appointment.set_cached(user, appointments)

      Rails.logger.info('mobile appointments service fetch', user_uuid: user.uuid)
      appointments
    end

    def latest_allowable_cache_start_date
      (@now.beginning_of_year - 1.year).to_datetime
    end

    def earliest_allowable_cache_end_date
      (@now.beginning_of_day + 1.year).to_datetime
    end

    private

    def fetch_from_external_service(user, start_date, end_date)
      if Flipper.enabled?(:mobile_appointment_use_VAOS_v2, user)
        v2_appointments_proxy(user).get_appointments(
          start_date: start_date,
          end_date: end_date,
          include_pending: true
        )
      else
        v0_appointments_proxy(user).get_appointments(start_date: start_date, end_date: end_date)
      end
    end

    # must break the cache if user is requesting dates beyond default range to ensure the integrity of the cache.
    # at this time, it's not possible for the user to fetch beyond this range because the interface doesn't allow it,
    # so the cache will effectively always be from beginning of last year until one year from today
    def use_cache?(start_date, end_date, use_cache)
      use_cache &&
        start_date == latest_allowable_cache_start_date &&
        end_date == earliest_allowable_cache_end_date
    end

    def v0_appointments_proxy(user)
      Mobile::V0::Appointments::Proxy.new(user)
    end

    def v2_appointments_proxy(user)
      Mobile::V2::Appointments::Proxy.new(user)
    end
  end
end
