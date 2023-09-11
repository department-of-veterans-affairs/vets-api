# frozen_string_literal: true

module Mobile
  class User < ApplicationRecord
    validates :icn, presence: true, uniqueness: true
    attribute :vet360_link_attempts, :integer, default: 0
    attribute :vet360_linked, :boolean, default: false

    def increment_vet360_link_attempts
      self.vet360_link_attempts += 1
    end
  end
end
