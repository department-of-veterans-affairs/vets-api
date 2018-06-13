# frozen_string_literal: true

module Authorization
  extend ActiveSupport::Concern

  def authorize(policy, method)
    Pundit.policy!(self, policy).send(method)
  end

  def authorize_messages(policy, method)
    Pundit.policy!(self, policy).rule_evaluations[method].messages
  end
end
