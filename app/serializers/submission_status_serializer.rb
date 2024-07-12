# frozen_string_literal: true

class SubmissionStatusSerializer
  include JSONAPI::Serializer

  attributes :id, :form_type, :status, :created_at, :updated_at

  # def read_attribute_for_serialization(attr)
  #   return object[attr.to_s]
  # end
end
