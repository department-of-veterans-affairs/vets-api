# frozen_string_literal: true

class StdInstitutionFacility < ApplicationRecord
  self.table_name = 'std_institution_facilities'

  scope :active, -> { where(deactivation_date: nil) }

  belongs_to :street_state, class_name: 'StdState', optional: true
  belongs_to :mailing_state, class_name: 'StdState', optional: true
end
