# frozen_string_literal: true

class LogService
  attr_reader :elapsed_time, :result, :span

  def initialize(tracer: Datadog::Tracing, logger: Rails.logger)
    @tracer = tracer
    @logger = logger
  end

  def call(action, tags: {}, &block)
    return if Rails.env.production?

    trace_and_annotate_action(action, tags) { time_action(&block) }
    log_timing_metric(action)
    result
  rescue => e
    handle_logging_error(action, e)
  end

  private

  def trace_and_annotate_action(action, tags)
    @tracer.trace(action) do |s|
      @span = s
      yield
      set_tags_and_metrics(action, tags)
    end
  end

  def set_tags_and_metrics(action, tags)
    tags.each { |key, value| span.set_tag(key, value) }
    span.set_metric("#{action}.time", (elapsed_time * 1000).to_i)
  end

  def time_action
    @elapsed_time = Benchmark.realtime { @result = yield }
  end

  def log_timing_metric(action)
    @logger.info("Timing for #{action}: #{(elapsed_time * 1000).to_i}ms")
  end

  def handle_logging_error(action, error)
    @logger.error("Error logging action #{action}: #{error.message}")
    span&.set_tag('error', true)
    span&.set_tag('error.msg', error.message)
    nil
  end
end
