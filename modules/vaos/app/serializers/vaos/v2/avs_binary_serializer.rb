# frozen_string_literal: true

module VAOS
  module V2
    class AvsBinarySerializer
      include JSONAPI::Serializer

      set_id :doc_id do |hash|
        hash[:doc_id]
      end

      set_type :avs_binary

      attribute :doc_id do |hash|
        hash[:doc_id]
      end
      attribute :binary, if: proc { |hash| !hash[:binary].nil? } do |hash|
        hash[:binary]
      end
      attribute :error, if: proc { |hash| !hash[:error].nil? } do |hash|
        hash[:error]
      end
    end
  end
end
