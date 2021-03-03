# frozen_string_literal: true

require 'claims_api/field_mapper_base'

module ClaimsApi
  class HomelessnessSituationTypeMapper < ClaimsApi::FieldMapperBase
    protected

    def items
      [
        { name: 'fleeing', code: 'FLEEING_CURRENT_RESIDENCE' },
        { name: 'shelter', code: 'LIVING_IN_A_HOMELESS_SHELTER' },
        { name: 'notShelter', code: 'NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT' },
        { name: 'anotherPerson', code: 'STAYING_WITH_ANOTHER_PERSON' },
        { name: 'other', code: 'OTHER' }
      ].freeze
    end
  end
end
