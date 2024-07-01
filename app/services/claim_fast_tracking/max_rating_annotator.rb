# frozen_string_literal: true

require 'virtual_regional_office/client'

module ClaimFastTracking
  class MaxRatingAnnotator
    SELECT_DISABILITIES = [ClaimFastTracking::DiagnosticCodes::TINNITUS].freeze

    def self.annotate_disabilities(rated_disabilities_response)
      return if rated_disabilities_response.rated_disabilities.blank?

      log_hyphenated_diagnostic_codes(rated_disabilities_response.rated_disabilities)

      diagnostic_codes = rated_disabilities_response.rated_disabilities
                                                    .compact # filter out nil entries in rated_disabilities
                                                    .map(&:diagnostic_code) # map to diagnostic_code field in rating
                                                    .select { |dc| dc.is_a?(Integer) } # select only integer values
                                                    .select { |dc| eligible_for_request?(dc) } # select only eligible
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
        Rails.logger.info('Max CFI rated disability',
                          diagnostic_code: dis&.diagnostic_code,
                          diagnostic_code_type: diagnostic_code_type(dis),
                          hyphenated_diagnostic_code: dis&.hyphenated_diagnostic_code)
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
      vro_client = VirtualRegionalOffice::Client.new
      response = vro_client.get_max_rating_for_diagnostic_codes(diagnostic_codes)
      response.body['ratings']
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "Get Max Ratings Failed  #{e.message}.", backtrace: e.backtrace
      nil
    end

    def self.eligible_for_request?(dc)
      Flipper.enabled?(:disability_526_maximum_rating_api_all_conditions) || SELECT_DISABILITIES.include?(dc)
    end

    private_class_method :get_ratings, :eligible_for_request?
  end
end
