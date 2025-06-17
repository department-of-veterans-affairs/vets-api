# frozen_string_literal: true

class LogService
  attr_reader :elapsed_time, :result, :span

  def initialize(tracer: Datadog::Tracing, logger: Rails.logger)
    @tracer = tracer
    @logger = logger
  end

  def call(action, tags: {}, &block)
    span = nil

    trace_and_annotate_action(action, tags) do |s|
      @span = span = s

      if block
        if block.arity == 1
          block.call(span)
        else
          @elapsed_time = Benchmark.realtime { @result = block.call }
        end
      end
    end

    log_timing_metric(action)
    result
  rescue => e
    handle_logging_error(action, e, span)
  end

  private

  def trace_and_annotate_action(action, tags)
    @tracer.trace(action) do |span|
      yield(span) if block_given?
      set_tags_and_metrics(span, action, tags)
    end
  end

  def set_tags_and_metrics(span, action, tags)
    tags.each { |key, value| span.set_tag(key.to_s, value.to_s) }

    # Prevent error if @elapsed_time is nil
    span.set_metric("#{action}.time", (elapsed_time * 1000).to_i) if elapsed_time
  end

  def log_timing_metric(action)
    @logger.info("Timing for #{action}: #{(elapsed_time * 1000).to_i}ms") if elapsed_time
  end

  def handle_logging_error(action, error, span)
    @logger.error("Error logging action #{action}: #{error.message}")
    if span
      span.set_tag('error', true)
      span.set_tag('error.msg', error.message)
      span.set_error(error) if span.respond_to?(:set_error)
    end
  end
end
