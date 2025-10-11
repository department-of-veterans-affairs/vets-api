# frozen_string_literal: true

module FormMappingsHelper
  def to_bin(value)
    value ? 0 : 1
  end
end
