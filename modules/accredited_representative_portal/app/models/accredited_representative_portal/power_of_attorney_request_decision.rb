# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecision < ApplicationRecord
    include PowerOfAttorneyRequestResolution::Resolving

    self.inheritance_column = nil

    module Types
      ALL = [
        ACCEPTANCE = 'PowerOfAttorneyRequestAcceptance',
        DECLINATION = 'PowerOfAttorneyRequestDeclination'
      ].freeze
    end

    belongs_to :creator, class_name: 'UserAccount'

    validates :type, inclusion: { in: Types::ALL }
  end
end
