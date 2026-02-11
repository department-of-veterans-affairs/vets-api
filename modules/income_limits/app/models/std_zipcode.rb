# frozen_string_literal: true

class StdZipcode < ApplicationRecord
  self.table_name = 'std_zipcodes'
  validates :id, presence: true, uniqueness: true
  validates :zip_code, presence: true
  validates :state_id, presence: true
  validates :county_number, presence: true
  validates :version, presence: true
  validates :created, presence: true

  scope :with_zip_code, lambda { |zip_code|
    where(zip_code:)
  }

  scope :for_state_id, lambda { |state_id|
    where(state_id:)
  }

  scope :for_zip_and_state, lambda { |zip_code, state_id|
    where(zip_code:, state_id:)
  }
end
