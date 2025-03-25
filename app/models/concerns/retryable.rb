# frozen_string_literal: true

module Retryable
  extend ActiveSupport::Concern

  DEFAULT_MAX_ATTEMPTS = 3
  DEFAULT_RETRY_DELAY = 1 # seconds

  def with_retries(block_name, max_attempts: DEFAULT_MAX_ATTEMPTS, retry_delay: DEFAULT_RETRY_DELAY, &block)
    attempts = 0

    begin
      attempts += 1
      result = block.call

      log_success(attempts, max_attempts, block_name) if attempts > 1
      result
    rescue => e
      handle_retry_exception(e, attempts, max_attempts, retry_delay, block_name)
      retry if attempts <= max_attempts
    end
  end

  private

  def log_success(attempts, max_attempts, block_name)
    Rails.logger.info("#{block_name} succeeded on attempt #{attempts}/#{max_attempts}")
  end

  def handle_retry_exception(e, attempts, max_attempts, retry_delay, block_name)
    if attempts <= max_attempts
      Rails.logger.warn("Retrying #{block_name} due to error: #{e.message} (Attempt #{attempts}/#{max_attempts})")
      sleep(retry_delay) if retry_delay.positive?
    else
      Rails.logger.error("#{block_name} failed after max retries", error: e.message, backtrace: e.backtrace)
      raise
    end
  end
end
