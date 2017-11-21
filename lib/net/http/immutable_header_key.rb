# frozen_string_literal: true
class Net::HTTP::ImmutableHeaderKey
  attr_reader :key

  def initialize(key)
    @key = key
  end

  def downcase
    self
  end

  def capitalize
    self
  end

  def capitalize!
    self
  end

  def split(*)
    [self]
  end

  delegate :hash, to: :key
  delegate :eql?, to: :key

  # rubocop:disable NestedMethodDefinition
  def to_s
    def self.to_s
      key
    end
    self
  end
  # rubocop:enable NestedMethodDefinition
end
