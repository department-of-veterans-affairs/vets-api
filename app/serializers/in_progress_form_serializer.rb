# frozen_string_literal: true

class InProgressFormSerializer < ActiveModel::Serializer
  # ensures that the attribute keys are camelCase, whether or not the Inflection header is sent
  attribute(:formId) { object.form_id }
  attribute(:createdAt) { object.created_at }
  attribute(:updatedAt) { object.updated_at }
  attribute(:metadata) { object.metadata }
  # NOTE: camelCasing all keys (deep transform) is *not* the goal. (see the InProgressFormsController for more details)
end
