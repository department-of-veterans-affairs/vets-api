# frozen_string_literal: true

##
# ReferralDetail represents the detailed information for a single referral from CCRA.
class ReferralDetail
  attr_reader :expiration_date, :type_of_care, :provider_name, :location,
              :number_of_appointments, :referral_number

  ##
  # Initializes a new instance of ReferralDetail.
  #
  # @param attributes [Hash] A hash containing the referral details from the CCRA response.
  # @option attributes [Hash] "Referral" The main referral data container.
  def initialize(attributes)
    referral = attributes['Referral']
    return if referral.blank?

    @expiration_date = referral['ReferralExpirationDate']
    @type_of_care = referral['CategoryOfCare']
    @provider_name = referral['TreatingProvider']
    @location = referral['TreatingFacility']
    @referral_number = referral['ReferralNumber']
  end
end
