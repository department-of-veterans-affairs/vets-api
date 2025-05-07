# frozen_string_literal: true

module Ccra
  # ReferralListEntry represents the essential referral data from the CCRA ReferralList endpoint.
  class ReferralListEntry
    attr_reader :category_of_care, :expiration_date
    attr_accessor :referral_number, :uuid, :referral_consult_id

    ##
    # Initializes a new instance of ReferralListEntry.
    #
    # @param attributes [Hash] A hash containing the referral details.
    # @option attributes [String] "CategoryOfCare" The type of care for the referral.
    # @option attributes [String] "ID" The unique identifier for the referral.
    # @option attributes [String] "StartDate" The start date of the referral.
    # @option attributes [String] "SEOCNumberOfDays" The number of days the referral is valid.
    def initialize(attributes)
      @category_of_care = attributes[:category_of_care]
      @referral_number = attributes[:referral_number]
      @referral_consult_id = attributes[:referral_consult_id]
      @uuid = nil # Will be set by controller
      @status = attributes[:status]
      @station_id = attributes[:station_id]
      @last_update_date_time = attributes[:referral_last_update_date_time]
      @expiration_date = parse_date(attributes[:referral_expiration_date])
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
