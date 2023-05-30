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
          letter[:letterType] = letter[:letterType].downcase
          letter[:name] = case letter[:letterType]
                          when 'benefit_summary'
                            'Benefit Summary and Service Verification Letter'
                          when 'benefit_summary_dependent'
                            'Dependent Benefit Summary and Service Verification Letter'
                          else
                            letter[:name]
                          end

          Mobile::V0::Letter.new(name: letter[:name], letter_type: letter[:letterType])
        end
      end
    end

    LettersStruct = Struct.new(:id, :letters)
  end
end
