# frozen_string_literal: true

class AppealsApi::JsonSchemaDefinitionName
  def initialize(def_name)
    @def_name = def_name
  end

  def to_swagger
    def_name && "#{def_name[0].upcase}#{def_name[1..]}"
  end

  private

  attr_reader :def_name
end
