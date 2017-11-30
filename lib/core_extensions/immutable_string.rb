# frozen_string_literal: true

module CoreExtensions
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
end
