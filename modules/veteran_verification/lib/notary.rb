# frozen_string_literal: true

require 'jwt'

module VeteranVerification
  class NotaryException < StandardError
  end

  class Notary
    def initialize(private_key_path)
      key_file = File.read(private_key_path)
      @keypair = OpenSSL::PKey::RSA.new(key_file)
    rescue SystemCallError, OpenSSL::PKey::RSAError => e
      raise NotaryException, "failed trying to initialize VeteranVerification::Notary with an RSA key #{e}"
    end

    def public_key
      @keypair.public_key
    end

    # This kid method is taken from the implementation of JWT::JWK in a future
    # version of the jwt gem. It provides a stable, deterministic kid for a
    # given public key
    def kid
      sequence = OpenSSL::ASN1::Sequence([OpenSSL::ASN1::Integer.new(public_key.n),
                                          OpenSSL::ASN1::Integer.new(public_key.e)])
      OpenSSL::Digest::SHA256.hexdigest(sequence.to_der)
    end

    def sign(payload)
      headers = { kid: kid }
      JWT.encode(payload, @keypair, 'RS256', headers)
    end
  end
end
