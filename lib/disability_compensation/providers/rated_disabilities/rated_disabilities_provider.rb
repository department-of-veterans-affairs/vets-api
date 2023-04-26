# frozen_string_literal: true

module RatedDisabilitiesProvider
  # @param [string] _client_id: the lighthouse_client_id requested from Lighthouse
  # @param [string] _rsa_key_path: path to the private RSA key used to create the lighthouse_client_id
  def self.get_rated_disabilities(_client_id = nil, _rsa_key_path = nil)
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
