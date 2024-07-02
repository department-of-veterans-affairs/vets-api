# frozen_string_literal: true

module Vye
  class PendingDocumentSerializer
    include JSONAPI::Serializer

    attributes :doc_type, :queue_date
  end
end
