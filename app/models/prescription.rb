# frozen_string_literal: true
require 'common/models/base'
# Prescription model
# Reference: https://github.com/department-of-veterans-affairs/prescriptions-team/blob/master/API/sample_mvh_api_calls
class Prescription < Common::Base
  attribute :prescription_id, Integer
  attribute :refill_status, String
  attribute :refill_submit_date, Common::UTCTime
  attribute :refill_date, Common::UTCTime
  attribute :refill_remaining, Integer
  attribute :facility_name, String
  attribute :ordered_date, Common::UTCTime
  attribute :quantity, Integer
  attribute :expiration_date, Common::UTCTime
  attribute :prescription_number, String
  attribute :prescription_name, String
  attribute :dispensed_date, Common::UTCTime
  attribute :station_number, String
  attribute :is_refillable, Boolean
  attribute :is_trackable, Boolean

  alias refillable? is_refillable
  alias trackable? is_trackable

  def <=>(other)
    return -1 if prescription_id < other.prescription_id
    return 1 if prescription_id > other.prescription_id
    0
  end
end
