# frozen_string_literal: true

require 'virtual_regional_office/client'

module ClaimFastTracking
  class MaxRatingAnnotator
    def self.annotate_disabilities(rated_disabilities_response)
      if Flipper.enabled?(:disability_526_maximum_rating_api)
        annotate_disabilities_api_enabled(rated_disabilities_response)
      else
        annotate_disabilities_api_disabled(rated_disabilities_response)
      end
    end

    def self.annotate_disabilities_api_disabled(rated_disabilities_response)
      tinnitus = ClaimFastTracking::DiagnosticCodes::TINNITUS
      rated_disabilities_response.rated_disabilities.each do |disability|
        disability.maximum_rating_percentage = 10 if disability.diagnostic_code == tinnitus
      end
    end

    def self.annotate_disabilities_api_enabled(rated_disabilities_response)
      diagnostic_codes = rated_disabilities_response.rated_disabilities.map(&:diagnostic_code)
      ratings = get_ratings(diagnostic_codes)
      if ratings.present?
        ratings.each do |rating|
          rated_disability = rated_disabilities_response.rated_disabilities.find do |disability|
            disability.diagnostic_code == rating['diagnostic_code']
          end
          rated_disability.maximum_rating_percentage = rating['max_rating'] if rated_disability.present?
        end
      end
      rated_disabilities_response
    end

    def self.get_ratings(diagnostic_codes)
      vro_client = VirtualRegionalOffice::Client.new
      response = vro_client.get_max_rating_for_diagnostic_codes(diagnostic_codes)
      response.body['ratings']
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "Get Max Ratings Failed  #{e.message}.", backtrace: e.backtrace
      nil
    end

    private_class_method :annotate_disabilities_api_disabled, :annotate_disabilities_api_enabled, :get_ratings
  end
end
