# frozen_string_literal: true

class Aes256CbcEncryptor
  def initialize(hex_secret, hex_iv)
    @secret = [hex_secret].pack('H*')
    @iv = [hex_iv].pack('H*')
    # Pad with zero bytes to correct length
    @secret << ("\x00" * (32 - secret.length))
    @iv << ("\x00" * (16 - iv.length))
  end

  attr_reader :secret, :iv

  def encrypt(payload)
    cipher = _encryption_cipher
    encrypted = cipher.update(payload) + cipher.final
    Base64.urlsafe_encode64(encrypted)
  end

  def decrypt(encrypted)
    cipher = _decryption_cipher
    encrypted_data = Base64.urlsafe_decode64(encrypted)
    cipher.update(encrypted_data) + cipher.final
  end

  private

  def _encryption_cipher
    encryption_cipher = _cipher
    encryption_cipher.encrypt
    encryption_cipher.key = @secret
    encryption_cipher.iv = @iv
    encryption_cipher
  end

  def _decryption_cipher
    decryption_cipher = _cipher
    decryption_cipher.decrypt
    decryption_cipher.key = @secret
    decryption_cipher.iv = @iv
    decryption_cipher
  end

  def _cipher
    OpenSSL::Cipher::AES.new(256, :CBC)
  end
end
