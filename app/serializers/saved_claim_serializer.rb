# frozen_string_literal: true

class SavedClaimSerializer < ActiveModel::Serializer
  attributes :id, :submitted_at, :regional_office, :confirmation_number, :guid
  attribute :form_id, key: :form
end
