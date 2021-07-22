# frozen_string_literal: true

unless Rails.env.test?
  # The CHIP API Request object methods that we wish to monitor
  chip_api_request_endpoints = %w[get post]

  Rails.application.reloader.to_prepare do
    # Increment StatsD when we call the CHIP API
    chip_api_request_endpoints.each do |endpoint|
      StatsD.increment("api.check_in.chip_api.request.#{endpoint}.total", 0)
      StatsD.increment("api.check_in.chip_api.request.#{endpoint}.fail", 0)
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
