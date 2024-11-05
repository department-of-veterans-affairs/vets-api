# frozen_string_literal: true

module SerializerSpecHelper
  def serialize(obj, opts = {})
    serializer_class = opts.delete(:serializer_class) || "#{obj.class.name}Serializer".constantize
    serializer_with_jsonapi(serializer_class, obj, opts)
  end

  def expect_time_eq(serialized_time, time)
    expect(serialized_time).to eq(time.iso8601(3))
  end

  def expect_data_eq(serialized_data, data)
    key_type = determine_key_type(serialized_data)
    expect(serialized_data).to eq(normalize_data(data, key_type))
  end

  private

  def determine_key_type(data)
    if data.is_a?(Array)
      first_element = data.find { |item| item.is_a?(Hash) }
      if first_element
        first_element.keys.first.is_a?(String) ? :string : :symbol
      end
    elsif data.is_a?(Hash)
      data.keys.first.is_a?(String) ? :string : :symbol
    end
  end

  def normalize_data(data, key_type)
    case data
    when Hash
      normalize_hash_keys(data, key_type)
    when Array
      data.map { |item| normalize_data(item, key_type) }
    else
      data
    end
  end

  def normalize_hash_keys(hash, key_type)
    case key_type
    when :string
      hash.deep_stringify_keys
    when :symbol
      hash.deep_symbolize_keys
    end
  end

  def serializer_with_jsonapi(serializer_class, obj, opts = {})
    serializer = serializer_class.new(obj, opts)
    serializer.serializable_hash.to_json
  end
end
