# frozen_string_literal: true

module VAOS
  module V2
    class AvsBinarySerializer
      include JSONAPI::Serializer

      set_id :doc_id

      set_type :avs_binary

      attributes :document_id,
                 :binary,
                 :error
    end
  end
end
