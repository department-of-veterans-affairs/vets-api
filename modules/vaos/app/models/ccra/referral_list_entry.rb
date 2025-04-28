# frozen_string_literal: true

module Ccra
  # ReferralListEntry represents the essential referral data from the CCRA ReferralList endpoint.
  class ReferralListEntry
    attr_reader :category_of_care, :expiration_date, :status, :station_id, :last_update_date_time
    attr_accessor :referral_number, :uuid

    ##
    # Initializes a new instance of ReferralListEntry.
    #
    # @param attributes [Hash] A hash containing the referral details.
    def initialize(attributes)
      @category_of_care = attributes['category_of_care']
      @referral_number = attributes['referral_number'] || attributes['referral_consult_id']
      @uuid = nil # Will be set by controller
      @status = attributes['status']
      @station_id = attributes['station_id']
      @last_update_date_time = attributes['referral_last_update_date_time']

      # If referral_expiration_date is directly provided, use it
      if attributes['referral_expiration_date'].present?
        @expiration_date = parse_date(attributes['referral_expiration_date'])
      # Otherwise calculate it from referral_date and days if available
      elsif attributes['referral_date'].present? && attributes['seoc_number_of_days'].present?
        start_date = parse_date(attributes['referral_date'])
        days = attributes['seoc_number_of_days'].to_i
        @expiration_date = start_date + days if start_date && days&.positive?
      end
    end

    ##
    # Creates an array of ReferralListEntry objects from an array of referral data.
    #
    # @param referrals [Array<Hash>] Array of referral data from the CCRA service.
    # @return [Array<ReferralListEntry>] Array of ReferralListEntry objects.
    def self.build_collection(referrals)
      Array(referrals).map { |referral_data| new(referral_data) }
    end

    private

    #
    # Parses the provided date string into a Date object.
    #
    # @param date_string [String] the date string to parse.
    # @return [Date, nil] the parsed Date if the input is valid; nil otherwise.
    def parse_date(date_string)
      return nil if date_string.blank?

      Date.parse(date_string)
    rescue Date::Error
      nil
    end
  end
end
