# frozen_string_literal: true

module Vye; end

class Vye::PendingDocumentSerializer < ActiveModel::Serializer
  attributes :doc_type, :queue_date
end
