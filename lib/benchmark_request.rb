# frozen_string_literal: true
class BenchmarkRequest
  include SentryLogging

  def initialize(request_name)
    @request_name = request_name
    @benchmark_key = "benchmark_#{request_name}"
    @redis = Redis.current
  end

  def benchmark
    start = Time.current
    return_val = yield
    diff = Time.current - start
    count_key = "#{@benchmark_key}.count"
    count = @redis.get(count_key)&.to_i
    average = @redis.get(@benchmark_key)

    if count.nil? || average.nil?
      count = 1
      average = diff
    else
      average = BigDecimal.new(average)
      total = average * count + diff
      count += 1
      average = total / count
    end

    @redis.set(@benchmark_key, average)
    @redis.set(count_key, count)

    log_benchmark(average, count)

    return_val
  end

  private

  def log_benchmark(average, count)
    log_message_to_sentry(
      "Average #{@request_name} request in seconds",
      :info,
      { average: average, count: count },
      backend_service: @request_name
    )
  end
end
