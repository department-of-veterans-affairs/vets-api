# frozen_string_literal: true

module CovidResearch
  class GenisisSerializer
    attr_reader :base

    def initialize
      @base = {
        GenISISId: 1,
        StudyId: 1,
        FormName: 'COVID-19',
        FormVersion: '1.0',
        FormSource: 'VA',
        FormFileName: nil
      }
    end

    def serialize(data)
      base[:FormQuestions] = formatted_qs(data)
      base[:CreatedDateTime] = timestamp
      base[:UpdatedDateTime] = timestamp

      JSON.generate(base)
    end

    private

    # There is some nesting in the submitted form data that doesn't
    #  map to genISIS well.  With this in mind we are recursively
    #  flattening the form submission into a list of key value pairs.
    #  There is currently nothing on the form nested more than one
    #  level deep.
    def formatted_qs(data)
      data.keys.map do |key|
        if data[key].class == Hash
          if key == 'veteranFullName'
            translate_name(data[key])
          else
            formatted_qs(data[key])
          end
        else
          {
            QuestionName: key,
            QuestionValue: data[key]
          }
        end
      end.flatten
    end

    def timestamp
      @timestamp ||= Time.now
    end

    private

    def translate_name(data)
      Volunteer::NameSerializer.new.serialize(data)
    end
  end
end
