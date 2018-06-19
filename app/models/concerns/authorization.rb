# frozen_string_literal: true

module Authorization
  extend ActiveSupport::Concern

  def authorize(policy, method)
    Pundit.policy!(self, policy).send(method)
  end

  def authorize_errors(policy, method)
    Pundit.policy!(self, policy).rule_evaluations[method].errors
  end
end
