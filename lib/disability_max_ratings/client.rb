# frozen_string_literal: true

require 'disability_max_ratings/configuration'

module DisabilityMaxRatings
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration DisabilityMaxRatings::Configuration

    STATSD_KEY_PREFIX = 'api.disability_max_ratings'

    def post_for_max_ratings(diagnostic_codes_array)
      with_monitoring do
        params = { diagnostic_codes: diagnostic_codes_array }
        perform(:post, Settings.disability_max_ratings_api.ratings_path, params.to_json, headers_hash)
      end
    end

    private

    def headers_hash
      {
        'Content-Type': 'application/json'
      }
    end
  end
end
