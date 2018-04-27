# frozen_string_literal: true

class InProgressFormSerializer < ActiveModel::Serializer
  attributes :form_id, :created_at, :updated_at, :metadata
end
