# frozen_string_literal: true

module MDOTHelpers
  def set_mdot_token_for(user, token = 'abcd1234abcd1234abcd1234')
    jwt = ::MDOT::Token.find_or_build(user.uuid)
    jwt.update(token: token, uuid: user.uuid)
  end
end
