# frozen_string_literal: true

class SavedClaimSerializer
  include JSONAPI::Serializer

  attributes :submitted_at, :regional_office, :confirmation_number, :guid

  attribute :form, &:form_id
end
