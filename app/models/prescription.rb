# frozen_string_literal: true

require 'common/models/base'
# Prescription model
# Reference: https://github.com/department-of-veterans-affairs/prescriptions-team/blob/master/API/sample_mvh_api_calls
class Prescription < Common::Base
  attribute :prescription_id, Integer, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :refill_status, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :refill_submit_date, Common::UTCTime, sortable: { order: 'DESC' }, filterable: %w(eq not_eq)
  attribute :refill_date, Common::UTCTime, sortable: { order: 'DESC' }
  attribute :refill_remaining, Integer
  attribute :facility_name, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :ordered_date, Common::UTCTime, sortable: { order: 'DESC' }
  attribute :quantity, Integer
  attribute :expiration_date, Common::UTCTime
  attribute :prescription_number, String
  attribute :prescription_name, String, sortable: { order: 'ASC', default: true }
  attribute :dispensed_date, Common::UTCTime, sortable: { order: 'DESC' }
  attribute :station_number, String
  attribute :is_refillable, Boolean
  attribute :is_trackable, Boolean

  alias refillable? is_refillable
  alias trackable? is_trackable

  def <=>(other)
    prescription_id <=> other.prescription_id
  end
end
