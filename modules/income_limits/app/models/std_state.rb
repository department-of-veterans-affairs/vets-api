# frozen_string_literal: true

class StdState < ApplicationRecord
  self.table_name = 'std_states'
  validates :id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :postal_name, presence: true
  validates :fips_code, presence: true
  validates :country_id, presence: true
  validates :version, presence: true
  validates :created, presence: true

  has_many :institution_facilities_street, class_name: 'StdInstitutionFacility', foreign_key: 'street_state_id'
  has_many :institution_facilities_mailing, class_name: 'StdInstitutionFacility', foreign_key: 'mailing_state_id'
end
