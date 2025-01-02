# frozen_string_literal: true

class SubmissionStatusSerializer
  include JSONAPI::Serializer

  attributes :id, :detail, :form_type, :message, :status, :created_at, :updated_at, :pdf_support
end
