# frozen_string_literal: true
class SavedClaimSerializer < ActiveModel::Serializer
  attributes :id, :submitted_at, :regional_office, :confirmation_number
  attribute :form_type, key: :form
end
