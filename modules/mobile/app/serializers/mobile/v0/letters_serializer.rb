# frozen_string_literal: true

module Mobile
  module V0
    class LettersSerializer
      include FastJsonapi::ObjectSerializer

      set_type :letters
      attributes :letters

      def initialize(id, letters, options = {})
        resource = LettersStruct.new(id, letters)
        super(resource, options)
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
