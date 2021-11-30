# frozen_string_literal: true

module Mobile
  module V0
    # Stores vaccine data from the CDC for use in Immunization records
    # @example create a new instance
    #   Mobile::V0::Vaccine.create(cvx_code: 1, group_name: 'FLU', manufacturer: 'Moderna')
    #
    class Vaccine < ApplicationRecord
      validates :cvx_code, presence: true, uniqueness: true
      validates :group_name, presence: true
    end
  end
end
