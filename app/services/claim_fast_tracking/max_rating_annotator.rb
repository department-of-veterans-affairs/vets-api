# frozen_string_literal: true

require 'disability_max_ratings/client'

module ClaimFastTracking
  class MaxRatingAnnotator
    EXCLUDED_DIGESTIVE_CODES = [7318, 7319, 7327, 7336, 7346].freeze

    def self.annotate_disabilities(rated_disabilities_response)
      return if rated_disabilities_response.rated_disabilities.blank?

      log_hyphenated_diagnostic_codes(rated_disabilities_response.rated_disabilities)

      diagnostic_codes = rated_disabilities_response.rated_disabilities
                                                    .compact # filter out nil entries in rated_disabilities
                                                    .select { |rd| eligible_for_request?(rd) } # select only eligible
                                                    .map(&:diagnostic_code) # map to diagnostic_code field in rating
      return rated_disabilities_response if diagnostic_codes.empty?

      ratings = get_ratings(diagnostic_codes)
      return rated_disabilities_response unless ratings

      ratings_hash = ratings.to_h { |rating| [rating['diagnostic_code'], rating['max_rating']] }
      rated_disabilities_response.rated_disabilities.each do |rated_disability|
        max_rating = ratings_hash[rated_disability.diagnostic_code]
        rated_disability.maximum_rating_percentage = max_rating if max_rating
      end
      rated_disabilities_response
    end

    def self.log_hyphenated_diagnostic_codes(rated_disabilities)
      rated_disabilities.each do |dis|
        StatsD.increment('api.max_cfi.rated_disability',
                         tags: [
                           "diagnostic_code:#{dis&.diagnostic_code}",
                           "diagnostic_code_type:#{diagnostic_code_type(dis)}",
                           "hyphenated_diagnostic_code:#{dis&.hyphenated_diagnostic_code}"
                         ])
      end
    end

    def self.diagnostic_code_type(rated_disability)
      case rated_disability&.diagnostic_code
      when nil
        :missing_diagnostic_code
      when 7200..7399
        :digestive_system
      when 6300..6399
        :infectious_disease
      else
        if (rated_disability&.hyphenated_diagnostic_code || 0) % 100 == 99
          :analogous_code
        else
          :primary_max_rating
        end
      end
    end

    def self.get_ratings(diagnostic_codes)
      disability_max_ratings_client = DisabilityMaxRatings::Client.new
      response = disability_max_ratings_client.post_for_max_ratings(diagnostic_codes)
      response.body['ratings']
    rescue Faraday::TimeoutError
      Rails.logger.error 'Get Max Ratings Failed: Request timed out.'
      nil
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "Get Max Ratings Failed  #{e.message}.", backtrace: e.backtrace
      nil
    end

    def self.eligible_for_request?(rated_disability)
      %i[infectious_disease missing_diagnostic_code].exclude?(diagnostic_code_type(rated_disability)) &&
        EXCLUDED_DIGESTIVE_CODES.exclude?(rated_disability.diagnostic_code)
    end

    private_class_method :get_ratings
  end
end
