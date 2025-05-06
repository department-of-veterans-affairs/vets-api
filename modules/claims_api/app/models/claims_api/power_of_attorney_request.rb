# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest < ApplicationRecord
    validates :proc_id, presence: true
    validates :veteran_icn, presence: true
    validates :poa_code, presence: true

    belongs_to :power_of_attorney, optional: true
  end
end
