module LoadTesting
  class Monitoring
    def initialize(test_session)
      @test_session = test_session
      @statsd = Datadog::Statsd.new('localhost', 8125)
    end

    def record_metrics(metrics)
      # Record to StatsD/Datadog
      @statsd.gauge('load_test.concurrent_users', metrics[:concurrent_users])
      @statsd.timing('load_test.response_time', metrics[:response_time])
      @statsd.increment('load_test.requests')
      
      if metrics[:error]
        @statsd.increment('load_test.errors')
      end

      # Store in database for analysis
      @test_session.metrics.create!(
        endpoint: metrics[:endpoint],
        response_time: metrics[:response_time],
        status: metrics[:status],
        error_message: metrics[:error_message],
        timestamp: Time.current
      )
    end

    def alert_if_needed(metrics)
      if error_rate_too_high?(metrics)
        notify_team("Error rate exceeded threshold: #{metrics[:error_rate]}%")
      end

      if response_time_too_high?(metrics)
        notify_team("Response time exceeded threshold: #{metrics[:response_time]}ms")
      end
    end

    private

    def error_rate_too_high?(metrics)
      metrics[:error_rate] > LoadTesting.configuration.error_threshold
    end

    def response_time_too_high?(metrics)
      metrics[:response_time] > LoadTesting.configuration.response_time_threshold
    end

    def notify_team(message)
      # Send to Slack
      SlackNotify.new(webhook_url: LoadTesting.configuration.slack_webhook_url)
                 .notify(message)
      
      # Create incident in PagerDuty if needed
      if LoadTesting.configuration.pagerduty_enabled
        PagerDuty.create_incident(
          title: "Load Test Alert",
          message: message,
          severity: "warning"
        )
      end
    end
  end
end 