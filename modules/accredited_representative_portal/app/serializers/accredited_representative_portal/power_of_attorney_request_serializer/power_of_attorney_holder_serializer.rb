# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    class PowerOfAttorneyHolderSerializer < ApplicationSerializer
      attribute :type do |poa_holder|
        case poa_holder
        when AccreditedIndividual
          "accredited_#{poa_holder.individual_type}"
        when AccreditedOrganization
          'veteran_service_organization'
        end
      end

      with_options if: proc { |poa_holder| poa_holder.is_a?(AccreditedOrganization) } do
        attribute :name
      end

      with_options if: proc { |poa_holder| poa_holder.is_a?(AccreditedIndividual) } do
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
end
