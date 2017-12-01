# frozen_string_literal: true
require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'

module EVSS
  module Letters
    class DownloadService < EVSS::Service
      configuration EVSS::Letters::DownloadConfiguration

      def download_letter(type, options = nil)
        with_monitoring do
          response = if options.blank?
                       perform(:get, type)
                     else
                       perform(:post, "#{type}/generate", options, 'Content-Type' => 'application/json')
                     end

          case response.status.to_i
          when 200
            response.body
          when 404
            raise Common::Exceptions::RecordNotFound, type
          else
            log_message_to_sentry(
              'EVSS letter generation failed', :error, extra_context: {
                url: config.base_path, body: response.body
              }
            )
            raise_backend_exception('EVSS502', 'Letters')
          end
        end
      end
    end
  end
end
