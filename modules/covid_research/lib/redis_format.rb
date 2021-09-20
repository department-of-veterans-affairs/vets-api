# frozen_string_literal: true

module CovidResearch
  class RedisFormat
    def initialize(crypto = Volunteer::FormCryptoService)
      @crypto = crypto.new
    end

    # @param json [String] the raw form submission (JSON format)
    # @return [String] the raw decrypted form submission
    def from_redis(json)
      json = JSON.parse(json)

      @form_data = Base64.decode64(json['form_data'])

      form_data
    end

    # @return [String] the raw decrypted form submission
    def form_data
      @crypto.decrypt_form(@form_data)
    end

    # @param data [String] the raw unencrypted form submission
    # @return [String] the encrypted form submission
    def form_data=(data)
      encrypted = @crypto.encrypt_form(data)

      @form_data = encrypted[:form_data]

      encrypted[:form_data]
    end

    # @param opts [Hash] a hash of opts for JSON generation (accepts `:only` and `:except`)
    # @return [String] JSON string representation of the encrypted form submission and "salt"
    def to_json(opts = {})
      h = {
        form_data: Base64.encode64(@form_data)
      }

      if opts[:only]
        h.keep_if { |key, _value| opts[:only].include key }
      elsif opts[:except]
        k.keep_if { |key, _value| !opts[:except].include(key) }
      end

      JSON.generate(h)
    end
  end
end
