# frozen_string_literal: true
class Net::HTTP::ImmutableKeysHash < Hash
  def [](key)
    result = self.select { |k, _v| k.key == key }
    result&.values.first
  end

  def []=(key, value)
    super(Net::HTTP::ImmutableHeaderKey.new(key), value)
  end
end
