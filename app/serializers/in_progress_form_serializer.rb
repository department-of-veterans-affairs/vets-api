# frozen_string_literal: true

class InProgressFormSerializer < ActiveModel::Serializer
  attribute(:formId) { object.form_id }
  attribute(:createdAt) { object.created_at }
  attribute(:updatedAt) { object.updated_at }
  attribute(:metadata) { object.metadata }
end
