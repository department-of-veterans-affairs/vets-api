# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class FacilitySerializer
      def serialize(json)
        json.keys.map do |key|
          case key
          when 'vaFacility'
            {
              QuestionName: 'preferredFacility',
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
