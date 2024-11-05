# frozen_string_literal: true

class StdInstitutionFacility < ApplicationRecord
  self.table_name = 'std_institution_facilities'

  scope :active, -> { where(deactivation_date: nil) }
end
