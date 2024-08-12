# frozen_string_literal: true

module Forms
  module SubmissionStatuses
    class ErrorHandler
      SOURCE = 'Lighthouse - Benefits Intake API'
      TITLE_PREFIX = 'Form Submission Status'

      def handle_error(response)
        errors = parse_error(response.status, response.body)
        return errors if errors.is_a?(Array)

        [errors]
      end

      def parse_error(status, body)
        error_msg = body.transform_keys(&:to_sym)

        case error_msg
        in { message: message }
          normalize(status:, title: title_from(status), detail: message)
        in { detail: detail }
          normalize(status:, title: title_from(status), detail:)
        in { errors: errors}
          # recursive call to normalize a collection of errors
          errors.map { |e| parse_error(status, e) }
        else
          normalize(status:, title: title_from(status), detail: detail_from(status))
        end
      end

      def normalize(status:, title:, detail:)
        {
          status:,
          source: SOURCE,
          title: "#{TITLE_PREFIX}: #{title}",
          detail:
        }
      end

      def title_from(status)
        case status
        when 401
          'Unauthorized'
        when 403
          'Forbidden'
        when 413
          'Request Entity Too Large'
        when 422
          'Unprocessable Content'
        when 429
          'Too Many Requests'
        when 500
          'Internal Server Error'
        when 502
          'Bad Gateway'
        when 504
          'Gateway Timeout'
        else
          'Unknown Error'
        end
      end

      alias detail_from title_from
    end
  end
end
