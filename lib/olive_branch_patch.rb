# frozen_string_literal: true

# This will monkey patch olivebranch middleware https://github.com/vigetlabs/olive_branch/blob/master/lib/olive_branch/middleware.rb
# so that when the VA inflection changes a key like something_va_something, the results will
# have the properly inflected somethingVASomething as well as support the old somethingVaSomething.
# This is a deprecation path and should be removed once consumers have adopted the inflection

module OliveBranchMiddlewareExtension
  def call(env)
    result = super(env)
    _status, _headers, response = result
    if env['HTTP_X_KEY_INFLECTION'] =~ /camel/i
      response.each do |json|
        # do not process strings that aren't json (like pdf responses)
        next unless json.is_a?(String) && json.starts_with?('{')

        duplicate_basic_va_keys!(json)
        duplicate_collection_va_keys!(json)
      end
    end
    result
  end

  private

  VA_KEY_VALUE_PAIR_REGEX = /("[^"]+VA[^"]*"):("[^"]*"|\d+|true|false|null)/.freeze

  def duplicate_basic_va_keys!(json)
    json.gsub!(VA_KEY_VALUE_PAIR_REGEX) do |va_key_value|
      key, value = va_key_value.split(':')
      "#{key}:#{value}, #{key.gsub('VA', 'Va')}:#{value}"
    end
  end

  VA_KEY_COLLECTION_REGEX = /("[^"]+VA[^"]*"):({|\[)/.freeze

  def duplicate_collection_va_keys!(json)
    keys_with_collections = []
    json.scan(VA_KEY_COLLECTION_REGEX) do |key, bracket_type|
      keys_with_collections << { key: key, bracket_type: bracket_type, sort_index: json.index(key) }
    end

    # replace them last to first, so that encapsulated collections will be duped
    keys_with_collections.sort { |info1, info2| info2[:sort_index] <=> info1[:sort_index] }.each do |info|
      key = info[:key]
      new_key_and_value = "#{key.gsub('VA', 'Va')}:#{collection_value(json, info[:key], info[:bracket_type])}, "
      json.insert(json.index(key), new_key_and_value)
    end
  end

  def collection_value(json, key, bracket_opener)
    bracket_closer = bracket_opener == '{' ? '}' : ']'
    index = json.index(key) + key.length
    object = json[index + 1]
    index += 2 # +2 for `:` and opening character
    needed_closures = 1
    while index < json.length
      char = json[index]
      object << char
      if char == bracket_opener
        needed_closures += 1
      elsif char == bracket_closer
        needed_closures -= 1
      end

      break if needed_closures.zero?

      index += 1
    end
    object
  end
end

module OliveBranch
  class Middleware
    prepend OliveBranchMiddlewareExtension
  end
end
