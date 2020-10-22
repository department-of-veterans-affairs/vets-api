# frozen_string_literal: true

# This will monkey patch olivebranch middleware https://github.com/vigetlabs/olive_branch/blob/master/lib/olive_branch/middleware.rb
# so that when the VA inflection changes a key like something_va_something, the results will
# have the properly inflected somethingVASomething as well as support the old somethingVaSomething.
# This is a deprecation path and should be removed once consumers have adopted the inflection

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
