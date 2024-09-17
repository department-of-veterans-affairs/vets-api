# frozen_string_literal: true

class GIBillFeedbackSerializer
  include JSONAPI::Serializer

  attributes :guid, :state, :parsed_response
end
