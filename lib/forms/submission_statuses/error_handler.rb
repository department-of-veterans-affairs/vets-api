# frozen_string_literal: true

module Forms
  module SubmissionStatuses
    class ErrorHandler
      SOURCE = 'Lighthouse - Benefits Intake API'
      TITLE_PREFIX = 'Form Submission Status'

      def handle_error(status:, body:)
        errors = parse_error(status, body)
        errors.is_a?(Array) ? errors : [errors]
      end

      def parse_error(status, body)
        error_msg = body.transform_keys(&:to_sym)
        title = self.class.title_from(status)

        case error_msg
        in { message: message }
          normalize(status:, title:, detail: message)
        in { detail: detail }
          normalize(status:, title:, detail:)
        in { errors: errors }
          # recursive call to normalize a collection of errors
          errors.map { |e| parse_error(status, e) }
        else
          normalize(status:, title:, detail: self.class.detail_from(status))
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

      class << self
        def title_from(status)
          status_titles = {
            401 => 'Unauthorized',
            403 => 'Forbidden',
            413 => 'Request Entity Too Large',
            422 => 'Unprocessable Content',
            429 => 'Too Many Requests',
            500 => 'Internal Server Error',
            502 => 'Bad Gateway',
            504 => 'Gateway Timeout'
          }

          status_titles.fetch(status, 'Unknown Error')
        end

        alias detail_from title_from
      end
    end
  end
end
