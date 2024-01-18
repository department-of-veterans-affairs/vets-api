# frozen_string_literal: true

module Vye
  class PendingDocumentSerializer < ActiveModel::Serializer
    attributes :doc_type, :queue_date
  end
end
