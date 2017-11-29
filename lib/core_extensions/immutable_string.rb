# frozen_string_literal: true

class ImmutableString < String
  def downcase
    self
  end

  def capitalize
    self
  end

  def to_s
    self
  end
end
