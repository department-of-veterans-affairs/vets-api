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
end
