# frozen_string_literal: true

module SchemaHelpers
  def read_schema(filename)
    JSON.parse(File.read(Rails.root.join('modules', 'appeals_api', 'config', 'schemas', filename)))
  end
end
