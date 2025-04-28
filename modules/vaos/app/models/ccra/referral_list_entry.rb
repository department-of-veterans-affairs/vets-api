# frozen_string_literal: true

module Ccra
  # ReferralListEntry represents the essential referral data from the CCRA ReferralList endpoint.
  class ReferralListEntry
    attr_reader :categoryOfCare, :expirationDate, :status, :stationId, :lastUpdateDateTime
    attr_accessor :referralNumber, :uuid

    ##
    # Initializes a new instance of ReferralListEntry.
    #
    # @param attributes [Hash] A hash containing the referral details.
    def initialize(attributes)
      @categoryOfCare = attributes['categoryOfCare']
      @referralNumber = attributes['referralNumber'] || attributes['referralConsultId']
      @uuid = nil # Will be set by controller
      @status = attributes['status']
      @stationId = attributes['stationId']
      @lastUpdateDateTime = attributes['referralLastUpdateDateTime']

      # If referral_expiration_date is directly provided, use it
      if attributes['referralExpirationDate'].present?
        @expirationDate = parse_date(attributes['referralExpirationDate'])
      # Otherwise calculate it from referral_date and days if available
      elsif attributes['referralDate'].present? && attributes['seocNumberOfDays'].present?
        start_date = parse_date(attributes['referralDate'])
        days = attributes['seocNumberOfDays'].to_i
        @expirationDate = start_date + days if start_date && days&.positive?
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
