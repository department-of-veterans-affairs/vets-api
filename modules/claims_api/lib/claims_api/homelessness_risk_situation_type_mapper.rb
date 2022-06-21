# frozen_string_literal: true

require 'claims_api/field_mapper_base'

module ClaimsApi
  class HomelessnessRiskSituationTypeMapper < ClaimsApi::FieldMapperBase
    protected

    def items
      [
        { name: 'losingHousing', code: 'HOUSING_WILL_BE_LOST_IN_30_DAYS' },
        { name: 'leavingShelter', code: 'LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE' },
        { name: 'other', code: 'OTHER' }
      ].freeze
    end
  end
end
