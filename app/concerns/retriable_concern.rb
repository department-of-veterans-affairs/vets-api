# frozen_string_literal: true

require 'retriable'

module RetriableConcern
  extend ActiveSupport::Concern

  def with_retries(block_name, tries: 3, base_interval: 1, &block)
    attempts = 0

    result = Retriable.retriable(tries:, base_interval:) do |attempt|
      attempts = attempt
      Rails.logger.warn("Retrying #{block_name} (Attempt #{attempts}/#{tries})") if attempts > 1
      block.call
    end

    Rails.logger.info("#{block_name} succeeded on attempt #{attempts}/#{tries}") if attempts > 1
    result
  rescue => e
    Rails.logger.error("#{block_name} failed after max retries", error: e.message, backtrace: e.backtrace)
    raise
  end
end
