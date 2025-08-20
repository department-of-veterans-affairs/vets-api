# frozen_string_literal: true

class AppealsApi::SupplementalClaimSerializer
  include JSONAPI::Serializer
  set_key_transform :camel_lower
  attributes :status, :updated_at, :created_at

  attribute :final_status, if: proc { |_, _|
    # The final_status will be serialized only if the decision_reviews_final_status_field flag is enabled
    Flipper.enabled?(:decision_reviews_final_status_field)
  } do |object, _|
    object.in_final_status?
  end

  # only return form_data for created records
  attribute :form_data, if: proc { |record| record.saved_change_to_id? }
  set_type :supplementalClaim
end
