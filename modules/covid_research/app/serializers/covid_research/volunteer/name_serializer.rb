# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class NameSerializer
      def serialize(json)
        json.keys.map do |key|
          case key
          when 'first'
            {
              QuestionName: 'firstName',
              QuestionValue: json[key]
            }
          when 'last'
            {
              QuestionName: 'lastName',
              QuestionValue: json[key]
            }
          else
            {
              QuestionName: key,
              QuestionValue: json[key]
            }
          end
        end
      end
    end
  end
end
