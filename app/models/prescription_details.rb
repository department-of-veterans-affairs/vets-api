# frozen_string_literal: true

require 'vets/model'

class PrescriptionDetails < Prescription
  attribute :cmop_division_phone, String
  attribute :in_cerner_transition, Bool
  attribute :not_refillable_display_message, String
  attribute :cmop_ndc_number, String
  attribute :user_id, Integer
  attribute :provider_first_name, String
  attribute :provider_last_name, String
  attribute :remarks, String
  attribute :division_name, String
  attribute :modified_date, Vets::Type::UTCTime
  attribute :institution_id, String
  attribute :dial_cmop_division_phone, String
  attribute :disp_status, String, filterable: %w[eq not_eq]
  attribute :ndc, String
  attribute :reason, String
  attribute :prescription_number_index, String
  attribute :prescription_source, String
  attribute :disclaimer, String
  attribute :indication_for_use, String
  attribute :indication_for_use_flag, String
  attribute :category, String
  attribute :tracking_list, Hash, array: true
  attribute :rx_rf_records, Hash, array: true
  attribute :tracking, Bool
  attribute :orderable_item, String
  attribute :sorted_dispensed_date, Date
  attribute :shape, String
  attribute :color, String
  attribute :back_imprint, String
  attribute :front_imprint, String
  attribute :grouped_medications, String, array: true

  def rx_rf_records=(records)
    @rx_rf_records = records&.dig(0, 1)
  end

  def tracking_list=(records)
    @tracking_list = records&.dig(0, 1)
  end

  def sorted_dispensed_date
    refill_dates = rx_rf_records&.map { |r| r[:dispensed_date]&.to_date }&.compact
    last_refill_date = refill_dates&.max

    @sorted_dispensed_date = last_refill_date || dispensed_date&.to_date
  end
end
