# frozen_string_literal: true

require 'vets/model'

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
#   @return [Vets::Type::UTCTime]
# @!attribute refill_date
#   @return [Vets::Type::UTCTime]
# @!attribute refill_remaining
#   @return [Integer]
# @!attribute facility_name
#   @return [String]
# @!attribute ordered_date
#   @return [Vets::Type::UTCTime]
# @!attribute quantity
#   @return [Integer]
# @!attribute expiration_date
#   @return [Vets::Type::UTCTime]
# @!attribute prescription_number
#   @return [String]
# @!attribute prescription_name
#   @return [String]
# @!attribute dispensed_date
#   @return [Vets::Type::UTCTime]
# @!attribute station_number
#   @return [String]
# @!attribute is_refillable
#   @return [Boolean]
# @!attribute is_trackable
#   @return [Boolean]
# @!attribute metadata
#   @return [Hash]
#
class Prescription
  include Vets::Model

  attribute :prescription_id, Integer, filterable: %w[eq not_eq]
  attribute :prescription_image, String
  attribute :refill_status, String, filterable: %w[eq not_eq]
  attribute :refill_submit_date, Vets::Type::UTCTime, filterable: %w[eq not_eq]
  attribute :refill_date, Vets::Type::UTCTime
  attribute :refill_remaining, Integer
  attribute :facility_name, String, filterable: %w[eq not_eq]
  attribute :facility_api_name, String
  attribute :ordered_date, Vets::Type::UTCTime
  attribute :quantity, Integer
  attribute :expiration_date, Vets::Type::UTCTime, filterable: %w[eq lteq gteq]
  attribute :prescription_number, String
  attribute :sig, String
  attribute :prescription_name, String
  attribute :dispensed_date, Vets::Type::UTCTime
  attribute :station_number, String
  attribute :is_refillable, Bool, filterable: %w[eq not_eq]
  attribute :is_trackable, Bool, filterable: %w[eq not_eq]
  attribute :cmop_division_phone, String
  attribute :metadata, Hash, default: -> { {} }

  default_sort_by prescription_id: :asc

  alias refillable? is_refillable
  alias trackable? is_trackable
end
