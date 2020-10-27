# frozen_string_literal: true

# This will monkey patch olivebranch middleware https://github.com/vigetlabs/olive_branch/blob/master/lib/olive_branch/middleware.rb
# so that when the VA inflection changes a key like something_va_something, the results will
# have the properly inflected somethingVASomething as well as support the old somethingVaSomething.
# This is a deprecation path and should be removed once consumers have adopted the inflection

module OliveBranchMiddlewareExtension
  # this regex captures keys with capital VA in the middle and the value.
  #   the value part optionally captures quotes around the value, but captures
  #   anything not a quote, comma, or closing brace so that numbers and booleans are captured

  # TODO: this regex is not catching "year_va_founded" and "lists_for_va" in the complicated example
  VA_KEY_VALUE_PAIR_REGEX = /\"([^"]+VA[^"]*)\":\"?([^("|,|\})]*)\"?/.freeze

  def call(env)
    result = super(env)
    _status, _headers, response = result
    if env['HTTP_X_KEY_INFLECTION'] =~ /camel/i
      response.each do |json|
        # do not process strings that aren't json (like pdf responses)
        next unless json.is_a?(String) && json.starts_with?('{')

        keys_with_collections = []
        json.gsub!(VA_KEY_VALUE_PAIR_REGEX) do |va_key_value|
          key, value = va_key_value.split(':')
          if value.starts_with?(/{|\[/)
            keys_with_collections << { key: key, opener: value.first, sort_index: json.index(key) }
            va_key_value
          else
            "#{key}:#{value}, #{key.gsub('VA', 'Va')}:#{value}"
          end
        end

        keys_with_collections.sort { |info1, info2| info2[:sort_index] <=> info1[:sort_index] }.each do |info|
          key = info[:key]
          key_index = json.index(key)
          new_key_and_value = "#{key.gsub('VA', 'Va')}:#{capture_collection(json, info)}, "
          json.insert(key_index, new_key_and_value)
        end
      end
    end
    result
  end

  private

  def capture_collection(json, key:, opener:, sort_index:)
    closer = opener == '{' ? '}' : ']'
    index = json.index(key) + key.length
    object = json[index + 1]
    index += 2 # +2 for `:` and opening character
    needed_closures = 1
    while index < json.length
      char = json[index]
      object << char
      if char == opener
        needed_closures += 1
      elsif char == closer
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
