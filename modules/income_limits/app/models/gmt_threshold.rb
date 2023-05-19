# frozen_string_literal: true

class GmtThreshold < ApplicationRecord
  self.table_name = 'gmt_thresholds'
  validates :id, presence: true, uniqueness: true
  validates :effective_year, presence: true
  validates :state_name, presence: true
  validates :county_name, presence: true
  validates :fips, presence: true
  validates :trhd1, presence: true
  validates :trhd2, presence: true
  validates :trhd3, presence: true
  validates :trhd4, presence: true
  validates :trhd5, presence: true
  validates :trhd6, presence: true
  validates :trhd7, presence: true
  validates :trhd8, presence: true
  validates :msa, presence: true
  validates :version, presence: true
  validates :created, presence: true
end
