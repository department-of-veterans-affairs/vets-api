# frozen_string_literal: true

module Mobile
  module V0
    class LettersSerializer
      include JSONAPI::Serializer

      COE_KEYS = %i[
        reference_number
        coe_status
      ].freeze

      set_type :letters
      attributes :letters

      def initialize(user, letters, options = {})
        resource = LettersStruct.new(user.uuid, filter_nil_fields(letters))

        super(resource, options)
      end

      # Filter out the coe fields that are nil to avoid sending them in the response
      def filter_nil_fields(letters)
        letters.map do |letter|
          letter_hash = letter.to_h.slice(:name, :letter_type)
          letter_hash.merge(letter.to_h.slice(*COE_KEYS).compact)
        end
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
