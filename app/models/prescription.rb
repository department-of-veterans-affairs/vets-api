# frozen_string_literal: true
require 'common/models/base'
# Prescription model
# Reference: https://github.com/department-of-veterans-affairs/prescriptions-team/blob/master/API/sample_mvh_api_calls
class Prescription < Common::Base
  attribute :prescription_id, Integer, sortable: true
  attribute :refill_status, String, sortable: true
  attribute :refill_submit_date, Common::UTCTime
  attribute :refill_date, Common::UTCTime, sortable: true
  attribute :refill_remaining, Integer
  attribute :facility_name, String, sortable: true
  attribute :ordered_date, Common::UTCTime, sortable: true
  attribute :quantity, Integer
  attribute :expiration_date, Common::UTCTime
  attribute :prescription_number, String
  attribute :prescription_name, String, sortable: true
  attribute :dispensed_date, Common::UTCTime
  attribute :station_number, String
  attribute :is_refillable, Boolean
  attribute :is_trackable, Boolean

  def self.default_sort
    '-ordered_date'
  end

  alias refillable? is_refillable
  alias trackable? is_trackable

  def <=>(other)
    prescription_id <=> other.prescription_id
  end
end
