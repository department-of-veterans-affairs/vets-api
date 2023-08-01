# frozen_string_literal: true

class PrescriptionDetails < Prescription
  attribute :cmop_division_phone, String
  attribute :in_cerner_transition, Boolean
  attribute :not_refillable_display_message, String
  attribute :cmop_ndc_number, String
  attribute :user_id, Integer
  attribute :provider_first_name, String
  attribute :provider_last_name, String
  attribute :remarks, String
  attribute :division_name, String
  attribute :modified_date, Common::UTCTime
  attribute :institution_id, String
  attribute :dial_cmop_division_phone, String
  attribute :disp_status, String
  attribute :ndc, String
  attribute :reason, String
  attribute :prescription_number_index, String
  attribute :prescription_source, String
  attribute :disclaimer, String
  attribute :indication_for_use, String
  attribute :indication_for_use_flag, String
  attribute :category, String
  attribute :tracking_list, Array[String]
  attribute :rx_rf_records, Array[String]
  attribute :tracking, Boolean
end
