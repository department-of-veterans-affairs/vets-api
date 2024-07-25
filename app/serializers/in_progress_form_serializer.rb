# frozen_string_literal: true

class InProgressFormSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :in_progress_forms

  # ensures that the attribute keys are camelCase, whether or not the Inflection header is sent
  # NOTE: camelCasing all keys (deep transform) is *not* the goal. (see the InProgressFormsController for more details)
  attribute :formId, &:form_id

  attribute :createdAt, &:created_at

  attribute :updatedAt, &:updated_at

  attribute :metadata, &:metadata
end
