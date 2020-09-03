# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/exceptions/record_not_found'
require 'evss/service'
require_relative 'download_configuration'

module EVSS
  module Letters
    ##
    # Proxy Service for Letters Download Caseflow
    #
    # @example Create a service and download letter by type
    #   letter_response = EVSS::Letters::DownloadService.new.download_letter("commissary")
    #
    class DownloadService < EVSS::Service
      include Common::Client::Concerns::Monitoring

      configuration EVSS::Letters::DownloadConfiguration

      ##
      # Downloads a letter for a user
      #
      # @param type [String] The type of letter to be downloaded;
      # one of EVSS::Letters::Letter::LETTER_TYPES
      # @return [String] Service response body
      #
      def download_letter(type, options = nil)
        with_monitoring do
          response = if options.blank?
                       download(type)
                     else
                       download_with_benefit_options(type, options)
                     end

          case response.status.to_i
          when 200
            response.body
          when 404
            raise Common::Exceptions::RecordNotFound, type
          else
            Raven.extra_context(
              url: config.base_path,
              body: response.body
            )
            raise_backend_exception('EVSS502', 'Letters')
          end
        end
      end

      private

      def download(type)
        perform(:get, type)
      end

      def download_with_benefit_options(type, options)
        perform(:post, "#{type}/generate", options, 'Content-Type' => 'application/json')
      end
    end
  end
end
