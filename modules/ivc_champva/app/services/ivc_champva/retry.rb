# frozen_string_literal: true

module IvcChampva
  class Retry
    # Generic retry mechanism for any method that needs to be repeated

    # @param [Integer] max_retries The maximum number of retries to make
    # @param [Integer] delay The delay in seconds between attempts
    # @param [Array] retry_on The error messages to retry on
    # @param [Proc] on_failure The block to call if all attempts fail
    # @yield The block to call
    def self.do(max_retries = 3, delay = 1, retry_on: nil, on_failure: nil, &block)
      retry_on = Array(retry_on) if retry_on

      attempts = 0

      begin
        block.call
      rescue => e
        on_failure&.call(e, attempts)
        if attempts < max_retries && (retry_on.nil? || retry_on.any? do |condition|
          e.message.downcase.include?(condition.downcase)
        end)
          attempts += 1
          Rails.logger.error "Retrying in #{delay} seconds..."
          sleep delay if delay.positive?
          retry
        end
      end
    end
  end
end
