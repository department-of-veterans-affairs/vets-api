# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    class IndividualPowerOfAttorneyHolderSerializer < ApplicationSerializer
      attribute :type do |poa_holder|
        "accredited_#{poa_holder.individual_type}"
      end

      attribute :full_name do |poa_holder|
        parts = [
          poa_holder.first_name,
          poa_holder.middle_initial,
          poa_holder.last_name
        ]

        parts.compact_blank.join(' ')
      end
    end
  end
end
