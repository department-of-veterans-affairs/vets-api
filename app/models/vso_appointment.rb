# frozen_string_literal: true

class VSOAppointment
  extend ActiveModel::Callbacks

  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  attribute :veteran_full_name, Preneeds::FullName
  attribute :veteran_ssn, String
  attribute :va_file_number, String
  attribute :insurance_number, String
  attribute :claimant_full_name, Preneeds::FullName
  attribute :claimant_address, Preneeds::Address
  attribute :claimant_email, String
  attribute :claimant_daytime_phone, String
  attribute :claimant_evening_phone, String
  attribute :relationship, String
  attribute :appointment_date, String
  attribute :organization_name, String
  attribute :organization_email, String
  attribute :organization_representative_name, String
  attribute :organization_representative_title, String
  attribute :disclosure_exception_drug_abuse, Boolean
  attribute :disclosure_exception_alcoholism, Boolean
  attribute :disclosure_exception_hiv, Boolean
  attribute :disclosure_exception_sickle_cell_anemia, Boolean

  validates :veteran_full_name, presence: true
  validates :veteran_ssn, presence: true
  validates :va_file_number, presence: true
  validates :insurance_number, presence: true
  validates :claimant_full_name, presence: true
  validates :claimant_address, presence: true
  validates :claimant_email, presence: true
  validates :claimant_daytime_phone, presence: true
  validates :claimant_evening_phone, presence: true
  validates :relationship, presence: true
  validates :appointment_date, presence: true, format: /\A\d{4}-\d{2}-\d{2}\Z/
  validates :organization_name, presence: true
  validates :organization_email, presence: true
  validates :organization_representative_name, presence: true
  validates :organization_representative_title, presence: true
end
