module LoadTesting
  class MetricsAnalyzer
    def initialize(test_session)
      @test_session = test_session
    end

    def analyze
      {
        summary: generate_summary,
        percentiles: calculate_percentiles,
        error_rates: calculate_error_rates,
        throughput: calculate_throughput
      }
    end

    private

    def generate_summary
      {
        total_requests: @test_session.metrics.count,
        total_duration: (@test_session.completed_at - @test_session.started_at).round(2),
        average_response_time: calculate_average_response_time,
        peak_concurrent_users: calculate_peak_concurrent_users
      }
    end

    def calculate_percentiles
      response_times = @test_session.metrics.pluck(:response_time).sort
      {
        p50: percentile(response_times, 50),
        p90: percentile(response_times, 90),
        p95: percentile(response_times, 95),
        p99: percentile(response_times, 99)
      }
    end

    def calculate_error_rates
      total = @test_session.metrics.count.to_f
      errors = @test_session.metrics.where(status: 'error').count
      {
        error_rate: (errors / total * 100).round(2),
        error_count: errors,
        error_breakdown: error_breakdown
      }
    end

    def calculate_throughput
      duration_minutes = (@test_session.completed_at - @test_session.started_at) / 60
      {
        requests_per_minute: (@test_session.metrics.count / duration_minutes).round(2),
        successful_requests_per_minute: (@test_session.metrics.where(status: 'success').count / duration_minutes).round(2)
      }
    end
  end
end 