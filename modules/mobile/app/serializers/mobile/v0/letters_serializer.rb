# frozen_string_literal: true

module Mobile
  module V0
    class LettersSerializer
      include JSONAPI::Serializer

      set_type :letters
      attributes :letters

      def initialize(user, letters, options = {})
        if Flipper.enabled?(:mobile_lighthouse_letters, user)
          letters = lighthouse_letters_serializer(letters)
        else
          letters = letters.map! do |letter|
            letter.name = 'Benefit Summary and Service Verification Letter' if letter.letter_type == 'benefit_summary'
            if letter.letter_type == 'benefit_summary_dependent'
              letter.name = 'Dependent Benefit Summary and Service Verification Letter'
            end
            letter
          end
        end
        resource = LettersStruct.new(user.uuid, letters)

        super(resource, options)
      end

      def lighthouse_letters_serializer(letters)
        letters.map do |letter|
          letter[:letter_type] = letter[:letter_type].downcase
          letter[:letter_name] = case letter[:letter_type]
                                 when 'benefit_summary'
                                   'Benefit Summary and Service Verification Letter'
                                 when 'benefit_summary_dependent'
                                   'Dependent Benefit Summary and Service Verification Letter'
                                 else
                                   letter[:letter_name]
                                 end

          Mobile::V0::Letter.new(name: letter[:letter_name], letter_type: letter[:letter_type])
        end
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
