# frozen_string_literal: true

module OliveBranchMiddlewareExtension
  VA_KEY_VALUE_PAIR_REGEX = %r[\\\"([^"]+VA[^"]*)\\\":\\\"([^"]*)\\\"].freeze
  def call(env)
    result = super(env)
    status, headers, response = result
    # if response.any? { |json| json =~ /VA/ }
    if env['HTTP_X_KEY_INFLECTION'] =~ /camel/i
      binding.pry
      # if response.any? { |json| json =~ /\\\"[^"]+VA.*\\\":/ }
      if response.is_a? Array
        response.each do |json|
          if match = json.match(VA_KEY_VALUE_PAIR_REGEX)
            key = match[1]
            value = match[2]
            json.gsub!(VA_KEY_VALUE_PAIR_REGEX, "\"#{key}\":\"#{value}\", \"#{key.gsub('VA', 'Va')}\":\"#{value}\"")
          end
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
