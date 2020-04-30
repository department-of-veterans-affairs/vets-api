# frozen_string_literal: true

class AppealsApi::JsonSchemaDefinitionName
  def initialize(definition_name, prefix: nil)
    @definition_name = definition_name
    @prefix = prefix
  end

  def to_swagger
    "#{prefix}#{definition_name}"
  end

  private

  def definition_name
    return nil if @definition_name.blank?

    "#{@definition_name[0].upcase}#{@definition_name[1..]}"
  end

  attr_reader :prefix
end
