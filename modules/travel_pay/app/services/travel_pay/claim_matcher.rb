# frozen_string_literal: true

module TravelPay
  # Helper module for matching travel pay claims to appointments
  module ClaimMatcher
    # Finds a matching claim for an appointment based on start time
    #
    # @param claims [Array] Array of claim hashes
    # @param appt_start [String] Appointment start time
    # @return [Hash, nil] Matching claim or nil
    def self.find_matching_claim(claims, appt_start)
      return nil if claims.nil?

      claims.find do |cl|
        claim_time = TravelPay::DateUtils.try_parse_date(cl['appointmentDateTime'])
        appt_time = TravelPay::DateUtils.strip_timezone(appt_start)

        claim_time.eql? appt_time
      end
    end
  end
end
