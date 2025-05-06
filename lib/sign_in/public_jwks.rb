# frozen_string_literal: true

module SignIn
  module PublicJwks
    private

    def jwks_loader(**options)
      if options[:kid_not_found]
        Rails.logger.info("#{config.log_prefix} JWK not found, reloading public JWKs")
        Rails.cache.delete_matched(config.jwks_cache_key)
        @public_jwks = nil
      end

      public_jwks
    end

    def public_jwks
      @public_jwks ||= Rails.cache.fetch(config.jwks_cache_key, expires_in: config.jwks_cache_expiration) do
        response = perform(:get, config.public_jwks_path, nil, nil)
        Rails.logger.info("#{config.log_prefix} Get Public JWKs Success")

        parse_public_jwks(response:)
      end
    rescue Common::Client::Errors::ClientError => e
      raise_client_error(e, 'Get Public JWKs')
    end

    def parse_public_jwks(response:)
      jwks = JWT::JWK::Set.new(response.body)
      jwks.select! { |key| key[:use] == 'sig' }
      jwks
    end
  end
end
