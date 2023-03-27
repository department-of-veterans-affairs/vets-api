# frozen_string_literal: true

# This will monkey patch olivebranch middleware https://github.com/vigetlabs/olive_branch/blob/master/lib/olive_branch/middleware.rb
# so that when the VA inflection changes a key like something_va_something, the results will
# have the old-inflection somethingVaSomething.

module OliveBranchMiddlewareExtension
  def call(env)
    result = super(env)
    _status, headers, response = result
    # olive branch uses this private method to determine if a tranformation should happen https://github.com/vigetlabs/olive_branch/blob/master/lib/olive_branch/middleware.rb#L92
    return result if send(:exclude_response?, env, headers)

    if env['HTTP_X_KEY_INFLECTION'] =~ /camel/i
      response.each do |json|
        un_camel_va_keys!(json)
      end
    end
    result
  end

  private

  VA_KEY_REGEX = /("[^"]+VA[^"]*"):/

  def un_camel_va_keys!(json)
    # rubocop:disable Style/PerlBackrefs
    # gsub with a block explicitly sets backrefs correctly https://ruby-doc.org/core-2.6.6/String.html#method-i-gsub
    json.gsub!(VA_KEY_REGEX) do
      key = $1
      "#{key.gsub('VA', 'Va')}:"
    end
    # rubocop:enable Style/PerlBackrefs
  end
end

module OliveBranch
  class Middleware
    prepend OliveBranchMiddlewareExtension
  end
end
