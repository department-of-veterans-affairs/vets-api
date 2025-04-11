# frozen_string_literal: true

module Ccra
  # ReferralListEntry represents the essential referral data from the CCRA ReferralList endpoint.
  class ReferralListEntry
    attr_reader :category_of_care, :referral_id, :expiration_date

    ##
    # Initializes a new instance of ReferralListEntry.
    #
    # @param attributes [Hash] A hash containing the referral details.
    # @option attributes [String] "CategoryOfCare" The type of care for the referral.
    # @option attributes [String] "ID" The unique identifier for the referral.
    # @option attributes [String] "StartDate" The start date of the referral.
    # @option attributes [String] "SEOCNumberOfDays" The number of days the referral is valid.
    def initialize(attributes)
      @category_of_care = attributes['CategoryOfCare'] || attributes['categoryOfCare']
      @referral_id = attributes['ID']

      start_date = parse_date(attributes['StartDate'])
      days = attributes['SEOCNumberOfDays'].to_i if attributes['SEOCNumberOfDays'].present?

      @expiration_date = start_date + days if start_date && days&.positive?
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
