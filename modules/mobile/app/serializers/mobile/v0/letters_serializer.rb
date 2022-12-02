# frozen_string_literal: true

module Mobile
  module V0
    class LettersSerializer
      include FastJsonapi::ObjectSerializer

      set_type :letters
      attributes :letters

      def initialize(id, letters, options = {})
        letters.map! do |letter|
          letter.name = 'Benefit Summary and Service Verification Letter' if letter.letter_type == 'benefit_summary'
          if letter.letter_type == 'benefit_summary_dependent'
            letter.name = 'Dependent Benefit Summary and Service Verification Letter'
          end
          letter
        end
        resource = LettersStruct.new(id, letters)
        super(resource, options)
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
