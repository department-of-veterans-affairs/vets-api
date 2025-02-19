# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    class OrganizationPowerOfAttorneyHolderSerializer < ApplicationSerializer
      attribute :type do
        'veteran_service_organization'
      end

      attribute :name
    end
  end
end
