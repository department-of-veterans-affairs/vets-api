# frozen_string_literal: true

module Mobile
  class AppointmentsCacheInterface
    def initialize
      @now = DateTime.now.utc
    end

    def fetch_appointments(user:, start_date: nil, end_date: nil, fetch_cache: true, cache_on_failures: true)
      appointments = nil
      search_start_date = [start_date, latest_allowable_cache_start_date].compact.min
      search_end_date = [end_date, earliest_allowable_cache_end_date].compact.max

      if fetch_cache?(search_start_date, search_end_date, fetch_cache)
        appointments = Mobile::V0::Appointment.get_cached(user)
        return [appointments, nil] if appointments
      end

      appointments, failures = fetch_from_external_service(user, search_start_date, search_end_date)

      Mobile::V0::Appointment.set_cached(user, appointments) if cache_on_failures == true || failures.blank?

      [appointments, failures]
    end

    # the mobile client can request appointments for as far back as the beginning of last year.
    def latest_allowable_cache_start_date
      (@now.beginning_of_year - 1.year).to_datetime
    end

    # when requesting future appointments, the mobile client requests (DateTime.local + 390.days).end_of_day
    def earliest_allowable_cache_end_date
      (@now.end_of_day + 390.days).to_datetime
    end

    private

    def fetch_from_external_service(user, start_date, end_date)
      appointments_proxy(user).get_appointments(
        start_date:,
        end_date:,
        include_pending: true
      )
    rescue => e
      raise Common::Exceptions::BadGateway.new(detail: e.errors.first&.detail)
    end

    # must break the cache if user is requesting dates beyond default range to ensure the integrity of the cache.
    # at this time, it's not possible for the user to fetch beyond this range because the interface doesn't allow it,
    # so the cache will effectively always be from beginning of last year until 390 days from today
    def fetch_cache?(start_date, end_date, fetch_cache)
      fetch_cache && dates_within_cache_range?(start_date, end_date)
    end

    def dates_within_cache_range?(start_date, end_date)
      start_date.to_date >= latest_allowable_cache_start_date.to_date &&
        end_date.to_date <= earliest_allowable_cache_end_date.to_date
    end

    def appointments_proxy(user)
      Mobile::V2::Appointments::Proxy.new(user)
    end
  end
end
