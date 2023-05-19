# frozen_string_literal: true

class StdZipcode < ApplicationRecord
  self.table_name = 'std_zipcodes'
  validates :id, presence: true, uniqueness: true
  validates :zip_code, presence: true
  validates :state_id, presence: true
  validates :county_number, presence: true
  validates :version, presence: true
  validates :created, presence: true
end
