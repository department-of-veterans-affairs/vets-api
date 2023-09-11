# frozen_string_literal: true

module ClaimsServiceProvider
  def self.all_claims
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
