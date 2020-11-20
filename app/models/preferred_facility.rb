class PreferredFacility < ApplicationRecord
  belongs_to :account, inverse_of: :preferred_facilities
end
