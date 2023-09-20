# frozen_string_literal: true

class DatadogLogger
  attr_reader :datadog_logger, :elapsed_time, :result, :span

  def initialize(host: 'localhost', port: 8125, namespace: 'AskVAApi')
    @datadog_logger = Datadog::Statsd.new(host, port, namespace:)
  end

  def call(action, tags: {}, &block)
    trace_and_annotate_action(action, tags) { time_action(&block) }
    log_timing_metric(action)
    result
  rescue => e
    handle_logging_error(action, e)
  end

  private

  def trace_and_annotate_action(action, tags)
    Datadog::Tracing.trace(action) do |s|
      @span = s
      yield
      set_tags_and_metrics(action, tags)
    end
  end

  def set_tags_and_metrics(action, tags)
    tags.each { |key, value| span.set_tag(key, value) }
    span.set_metric("#{action}.time", elapsed_time * 1000)
  end

  def time_action
    @elapsed_time ||= Benchmark.realtime { @result = yield }
  end

  def log_timing_metric(action)
    datadog_logger.timing("#{action}.time", elapsed_time * 1000)
  end

  def handle_logging_error(action, error)
    Raven.capture_exception(error, extra: { action: })
    Rails.logger.error("Error logging action #{action}: #{error.message}")
    span&.set_tag('error', true)
    span&.set_tag('error.msg', error.message)
    nil
  end
end
