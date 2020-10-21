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

        if match = json.match(VA_KEY_VALUE_PAIR_REGEX)
          key = match[1]
          value = match[2]
          json.gsub!(VA_KEY_VALUE_PAIR_REGEX, "\"#{key}\":\"#{value}\", \"#{key.gsub('VA', 'Va')}\":\"#{value}\"")
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
