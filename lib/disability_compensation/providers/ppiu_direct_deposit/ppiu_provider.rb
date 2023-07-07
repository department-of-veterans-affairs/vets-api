# frozen_string_literal: true

module PPIUProvider
  def self.get_payment_information(_client_id = nil, _rsa_key_path = nil)
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
