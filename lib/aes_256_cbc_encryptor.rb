# frozen_string_literal: true

class Aes256CbcEncryptor
  def initialize(hex_secret, hex_iv)
    @secret = [hex_secret].pack('H*')
    @iv = [hex_iv].pack('H*')
    raise ArgumentError, 'Secret must be 32 bytes.' unless @secret.length == 32
    raise ArgumentError, 'IV must be 16 bytes.' unless @iv.length == 16
  end

  attr_reader :secret, :iv

  def encrypt(payload)
    cipher = encryption_cipher
    encrypted = cipher.update(payload) + cipher.final
    Base64.urlsafe_encode64(encrypted)
  end

  def decrypt(encrypted)
    cipher = decryption_cipher
    encrypted_data = Base64.urlsafe_decode64(encrypted)
    cipher.update(encrypted_data) + cipher.final
  end

  private

  def encryption_cipher
    cipher(:encrypt)
  end

  def decryption_cipher
    cipher(:decrypt)
  end

  def cipher(type)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.send(type)
    cipher.key = @secret
    cipher.iv = @iv
    cipher
  end
end
