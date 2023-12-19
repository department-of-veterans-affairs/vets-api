# frozen_string_literal: true

require 'base64'
require 'openssl'

module Vye; end

module Vye::GenDigest
  extend ActiveSupport::Concern

  module Common
    GEN_DIGEST_CONFIG =
      [Settings.vye.scrypt, %i[salt N r p length]]
      .then { |s, l| l.collect { |m| [m, s.send(m)] } }
      .then { |pairs| Hash[*pairs.flatten] }
      .freeze

    def gen_digest(value)
      value&.then { |v| Base64.encode64(OpenSSL::KDF.scrypt(v, **GEN_DIGEST_CONFIG)).strip }
    end
  end

  included do
    extend Common
    include Common
  end
end
