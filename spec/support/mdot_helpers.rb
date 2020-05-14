# frozen_string_literal: true

module MDOT
  module Helpers
    def set_token_for(user, token='abcd1234abcd1234abcd1234')
      token = ::MDOT::Token.find_or_build(user.uuid)
      token.update(token: token)
    end
  end
end
