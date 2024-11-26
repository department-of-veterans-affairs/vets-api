# frozen_string_literal: true

require 'common/models/base'

##
# Models a Prescription
#
# @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Rx%20Refills/API/sample_mvh_api_calls
#
# @!attribute prescription_id
#   @return [Integer]
# @!attribute refill_status
#   @return [String]
# @!attribute refill_submit_date
#   @return [Common::UTCTime]
# @!attribute refill_date
#   @return [Common::UTCTime]
# @!attribute refill_remaining
#   @return [Integer]
# @!attribute facility_name
#   @return [String]
# @!attribute ordered_date
#   @return [Common::UTCTime]
# @!attribute quantity
#   @return [Integer]
# @!attribute expiration_date
#   @return [Common::UTCTime]
# @!attribute prescription_number
#   @return [String]
# @!attribute prescription_name
#   @return [String]
# @!attribute dispensed_date
#   @return [Common::UTCTime]
# @!attribute station_number
#   @return [String]
# @!attribute is_refillable
#   @return [Boolean]
# @!attribute is_trackable
#   @return [Boolean]
#
class Prescription < Common::Base
  attribute :prescription_id, Integer, sortable: { order: 'ASC' }, filterable: %w[eq not_eq]
  attribute :prescription_image, String
  attribute :refill_status, String, sortable: { order: 'ASC' }, filterable: %w[eq not_eq]
  attribute :refill_submit_date, Common::UTCTime, sortable: { order: 'DESC' }, filterable: %w[eq not_eq]
  attribute :refill_date, Common::UTCTime, sortable: { order: 'DESC' }
  attribute :refill_remaining, Integer
  attribute :facility_name, String, sortable: { order: 'ASC' }, filterable: %w[eq not_eq]
  attribute :facility_api_name, String
  attribute :ordered_date, Common::UTCTime, sortable: { order: 'DESC' }
  attribute :quantity, Integer
  attribute :expiration_date, Common::UTCTime, filterable: %w[eq lteq gteq]
  attribute :prescription_number, String
  attribute :sig, String
  attribute :prescription_name, String, sortable: { order: 'ASC', default: true }
  attribute :dispensed_date, Common::UTCTime, sortable: { order: 'DESC' }
  attribute :station_number, String
  attribute :is_refillable, Boolean, filterable: %w[eq not_eq]
  attribute :is_trackable, Boolean, filterable: %w[eq not_eq]
  attribute :cmop_division_phone, String

  alias refillable? is_refillable
  alias trackable? is_trackable

  def <=>(other)
    prescription_id <=> other.prescription_id
  end
end
