# frozen_string_literal: true

module Mobile
  module V0
    class LettersSerializer
      include JSONAPI::Serializer

      set_type :letters
      attributes :letters

      def initialize(user, letters, options = {})
        resource = LettersStruct.new(user.uuid, letters)

        super(resource, options)
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
