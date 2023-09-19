# frozen_string_literal: true

class AppealsApi::SupplementalClaims::V0::SupplementalClaimSerializer
  include JSONAPI::Serializer
  set_key_transform :camel_lower
  set_type :supplementalClaim
  attributes :status
  # These names are required by Lighthouse standards
  attribute :createDate, &:created_at
  attribute :updateDate, &:updated_at
  # Only return form_data for created records
  attribute :form_data, if: proc { |record| record.saved_change_to_id? }
end
