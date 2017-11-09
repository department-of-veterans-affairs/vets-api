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

  def eql?(other)
    key.eql? other.key.eql?
  end

  def to_s
    self.to_s = -> { key }
    to_s.call
  end
end
