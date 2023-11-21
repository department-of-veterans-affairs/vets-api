# frozen_string_literal: true

module Mobile
  module V0
    class LetterSerializer
      include JSONAPI::Serializer

      set_type :letter
      attributes :letter

      def initialize(user_uuid, letter)
        resource = LetterStruct.new(user_uuid, letter)
        super(resource)
      end
    end
    LetterStruct = Struct.new(:id, :letter)
  end
end
