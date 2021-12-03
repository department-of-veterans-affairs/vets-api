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
      base[:CreatedDateTime] = timestamp.iso8601
      base[:UpdatedDateTime] = timestamp.iso8601

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
        if key == 'veteranFullName'
          translate_name(data[key])
        elsif data[key].instance_of?(Hash)
          formatted_qs(data[key])
        else
          {
            QuestionName: key,
            QuestionValue: value(data[key])
          }
        end
      end.flatten
    end

    def timestamp
      @timestamp ||= Time.now.utc
    end

    def translate_name(data)
      Volunteer::NameSerializer.new.serialize(data)
    end

    def value(actual)
      case actual
      when true
        'Yes'
      when false
        'No'
      else
        actual.to_s
      end
    end
  end
end
