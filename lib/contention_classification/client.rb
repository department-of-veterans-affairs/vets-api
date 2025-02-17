# frozen_string_literal: true

require 'contention_classification/configuration'

module ContentionClassification
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration ContentionClassification::Configuration

    STATSD_KEY_PREFIX = 'api.contention_classification'

    def classify_vagov_contentions_expanded(params)
      with_monitoring do
        perform(:post, Settings.contention_classification_api.expanded_contention_classification_path,
                params.to_json, request_headers)
      end
    rescue Faraday::Error => e
      Rails.logger.error(
        'ContentionClassification::Client Faraday error on path ' \
        "#{Settings.contention_classification_api.expanded_contention_classification_path}: #{e.message}"
      )
      raise e
    end

    private

    def request_headers
      {
        'Content-Type': 'application/json'
      }
    end
  end
end
