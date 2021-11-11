# frozen_string_literal: true

unless Rails.env.test?

  Rails.application.reloader.to_prepare do
    # duration/success/fail of GET, POST calls for controllers
    CheckIn::V2::SessionsController.extend(StatsD::Instrument)
    CheckIn::V2::PatientCheckInsController.extend(StatsD::Instrument)
    %i[show create].each do |method|
      CheckIn::V2::SessionsController.statsd_measure method, "api.check_in.v2.sessions.#{method}.measure"
      CheckIn::V2::SessionsController.statsd_count_success method, "api.check_in.v2.sessions.#{method}.count"
      CheckIn::V2::PatientCheckInsController.statsd_measure method, "api.check_in.v2.checkins.#{method}.measure"
      CheckIn::V2::PatientCheckInsController.statsd_count_success method, "api.check_in.v2.checkins.#{method}.count"
    end

    # Measure the count/duration of GET/POST calls for LoROTA/CHIP services
    V2::Lorota::Client.extend(StatsD::Instrument)
    %i[token data].each do |method|
      V2::Lorota::Client.statsd_count_success method, "api.check_in.v2.lorota.#{method}.count"
      V2::Lorota::Client.statsd_measure method, "api.check_in.v2.lorota.#{method}.measure"
    end

    V2::Chip::Request.extend(StatsD::Instrument)
    %i[get post].each do |method|
      V2::Chip::Request.statsd_count_success method, "api.check_in.v2.chip.#{method}.count"
      V2::Chip::Request.statsd_measure method, "api.check_in.v2.chip.#{method}.measure"
    end

    # Measure the duration of GET and POST calls for Check-in data to the CHIP API
    ChipApi::Service.extend(StatsD::Instrument)
    ChipApi::Service.statsd_measure :get_check_in, 'check_in.chip_api.get_check_in.measure'
    ChipApi::Service.statsd_measure :create_check_in, 'check_in.chip_api.create_check_in.measure'

    # Measure the duration of POST calls to the CHIP API for JWT access tokens
    ChipApi::Token.extend(StatsD::Instrument)
    ChipApi::Token.statsd_measure :fetch, 'check_in.chip_api.fetch_token.measure'
  end
end
