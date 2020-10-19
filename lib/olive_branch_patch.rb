# frozen_string_literal: true

module OliveBranchMiddlewareExtension
  def call(env)
    result = super(env)
    status, headers, response = result
    # if response.any? { |json| json =~ /VA/ }
    if env["HTTP_X_KEY_INFLECTION"] =~ /camel/i
      binding.pry
      if response.any? { |json| json =~ /\\\"[^"]+VA.*\\\":/ }
        binding.pry
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
