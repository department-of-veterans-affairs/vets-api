# frozen_string_literal: true

class StdIncomeThreshold < ApplicationRecord
  self.table_name = 'std_incomethresholds'
  validates :id, presence: true, uniqueness: true
  validates :income_threshold_year, presence: true
  validates :exempt_amount, presence: true
  validates :medical_expense_deductible, presence: true
  validates :child_income_exclusion, presence: true
  validates :dependent, presence: true
  validates :add_dependent_threshold, presence: true
  validates :property_threshold, presence: true
  validates :version, presence: true
  validates :created, presence: true
end
