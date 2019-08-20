# frozen_string_literal: true

module ClaimsApi
  module RequestLogging
    extend ActiveSupport::Concern
    # rubocop:disable Metrics/BlockLength
    included do
      before_action :log_request

      def log_request
        if @current_user.present?
          hashed_ssn = Digest::SHA2.hexdigest @current_user.ssn
          Rails.logger.info('Claims App Request', 'lookup_identifier' => hashed_ssn)
        else
          hashed_ssn = Digest::SHA2.hexdigest ssn
          Rails.logger.info('Claims App Request',
                            'consumer' => consumer,
                            'va_user' => requesting_va_user,
                            'lookup_identifier' => hashed_ssn)
        end
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
    # rubocop:enable Metrics/BlockLength
  end
end
