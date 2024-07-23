# frozen_string_literal: true

class AppealsApi::SupplementalClaims::V0::SupplementalClaimSerializerWithPii
  include JSONAPI::Serializer
  set_key_transform :camel_lower
  set_type :supplementalClaim
  attributes :status
  attribute :code, if: proc { |sc| sc.status == 'error' }
  attribute :detail, if: proc { |sc| sc.status == 'error' }
  # These names are required by Lighthouse standards
  attribute :createDate, &:created_at
  attribute :updateDate, &:updated_at
  # Only return form_data for created records
  attribute :form_data, if: proc { |record| record.saved_change_to_id? }
end
