# frozen_string_literal: true

module Vye
  class PendingDocumentSerializer
    def initialize(resource)
      @resource = resource
    end

    def to_json(*)
      Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
    end

    def serializable_hash
      {
        doc_type: @resource.doc_type,
        queue_date: @resource.queue_date
      }
    end
  end
end
