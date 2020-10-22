# frozen_string_literal: true

module OliveBranchMiddlewareExtension
  VA_KEY_VALUE_PAIR_REGEX = /\"([^"]+VA[^"]*)\":\"([^"]*)\"/.freeze
  def call(env)
    result = super(env)
    _status, _headers, response = result
    if env['HTTP_X_KEY_INFLECTION'] =~ /camel/i
      response.each do |json|
        # do not process strings that aren't json (like pdf responses)
        next unless json.is_a?(String) && json.starts_with?('{')

        json.gsub!(VA_KEY_VALUE_PAIR_REGEX) do |va_key_value|
          # key = $1
          # value = $2
          key, value = va_key_value.split(':')
          "#{key}:#{value}, #{key.gsub('VA', 'Va')}:#{value}"
        end
      end
    end
    result
  end
end

module OliveBranch
  class Middleware
    prepend OliveBranchMiddlewareExtension
  end
end
