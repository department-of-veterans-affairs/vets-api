# frozen_string_literal: true
host = ENV['STATSD_HOST']
port = ENV['STATSD_PORT']

StatsD.backend = if host.present? && port.present?
                   StatsD::Instrument::Backends::UDPBackend.new("#{host}:#{port}", :statsd)
                 else
                   StatsD::Instrument::Backends::LoggerBackend.new(Rails.logger)
                 end
