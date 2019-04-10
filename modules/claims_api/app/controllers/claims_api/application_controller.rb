# frozen_string_literal: true

module ClaimsApi
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false
    before_action :log_request

    private

    def log_request
      hashed_ssn = Digest::SHA2.hexdigest ssn
      Rails.logger.info('Claims App Request',
                        'consumer' => consumer,
                        'va_user' => requesting_va_user,
                        'lookup_identifier' => hashed_ssn)
    end

    def log_response(additional_fields = {})
      logged_info = {
        'consumer' => consumer,
        'va_user' => requesting_va_user
      }.merge(additional_fields)
      Rails.logger.info('Claims App Response', logged_info)
    end

    def consumer
      header(key = 'X-Consumer-Username') ? header(key) : raise_missing_header(key)
    end

    def ssn
      header(key = 'X-VA-SSN') ? header(key) : raise_missing_header(key)
    end

    def requesting_va_user
      header('X-VA-User') || header('X-Consumer-Username')
    end

    def header(key)
      request.headers[key]
    end

    def raise_missing_header(key)
      raise Common::Exceptions::ParameterMissing, key
    end
  end
end
