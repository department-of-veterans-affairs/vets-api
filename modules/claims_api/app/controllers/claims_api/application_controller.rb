# frozen_string_literal: true

module ClaimsApi
  class ApplicationController < ::ApplicationController
    skip_before_action :set_tags_and_extra_context
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
      Rails.logger.info('Appeals App Response', logged_info)
    end

    def consumer
      request.headers['X-Consumer-Username']
    end

    def ssn
      ssn = request.headers['X-VA-SSN']
      raise Common::Exceptions::ParameterMissing, 'X-VA-SSN' unless ssn
      ssn
    end

    def requesting_va_user
      va_user = request.headers['X-VA-User']
      raise Common::Exceptions::ParameterMissing, 'X-VA-User' unless va_user
      va_user
    end
  end
end
