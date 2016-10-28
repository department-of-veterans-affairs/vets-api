# frozen_string_literal: true
StatsD.backend = if Rails.env.development? || Rails.env.test?
                   StatsD::Instrument::Backends::LoggerBackend.new(Rails.logger)
                 else
                   StatsD::Instrument::Backends::UDPBackend.new("#{ENV['STATSD_HOST']}:#{ENV['STATSD_PORT']}", :statsd)
                 end
