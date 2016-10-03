# frozen_string_literal: true
require 'common/models/base'
# Tracking Model
class Tracking < Common::Base
  attribute :prescription_id, Integer
  attribute :prescription_name, String
  attribute :prescription_number, String
  attribute :facility_name, String
  attribute :rx_info_phone_number, String
  attribute :ndc_number, String
  attribute :shipped_date, Common::UTCTime, sortable: true
  attribute :delivery_service, String
  attribute :tracking_number, String

  def self.default_sort
    '-shipped_date'
  end

  def <=>(other)
    shipped_date <=> other.shipped_date
  end
end
