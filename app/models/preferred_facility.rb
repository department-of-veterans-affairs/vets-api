class PreferredFacility < ApplicationRecord
  belongs_to :account, inverse_of: :preferred_facilities

  validates(:account, :facility_code, presence: true)
end
