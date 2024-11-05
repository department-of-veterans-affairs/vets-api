# frozen_string_literal: true

module Mobile
  module V0
    class EfolderSerializer
      include JSONAPI::Serializer

      set_type :efolder_document
      attributes :doc_type,
                 :type_description,
                 :received_at
    end
  end
end
