# frozen_string_literal: true

class Auth
  def self.authorized?(user, policy, method)
    Pundit.policy!(user, policy).send(method)
  end
end
