# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ServiceBase
    include Sidekiq::Job

    RETRY_STATUS_CODES = %w[500 502 503 504].freeze

    protected

    def get_error_message(error)
      if error.respond_to? :original_body
        error.original_body
      elsif error.respond_to? :message
        error.message
      else
        error
      end
    end

    def get_original_status_code(error)
      if error.respond_to? :original_status
        error.original_status
      else
        ''
      end
    end

    def will_retry_status_code?(error)
      status = get_original_status_code(error)
      RETRY_STATUS_CODES.include?(status.to_s)
    end
  end
end
