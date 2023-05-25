# frozen_string_literal: true

class StdCounty < ApplicationRecord
  self.table_name = 'std_counties'
  validates :id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :county_number, presence: true
  validates :description, presence: true
  validates :state_id, presence: true
  validates :version, presence: true
  validates :created, presence: true
end
