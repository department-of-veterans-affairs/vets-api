# frozen_string_literal: true

module SignIn
  class IntrospectSerializer < ActiveModel::Serializer
    attributes :active, :anti_csrf_token, :aud, :client_id, :exp, :iat, :iss, :jti,
               :last_regeneration_time, :parent_refresh_token_hash, :refresh_token_hash,
               :session_handle, :sub, :user_attributes, :version

    delegate :anti_csrf_token, to: :object
    delegate :audience, to: :object
    delegate :client_id, to: :object
    delegate :created_time, to: :object
    delegate :expiration_time, to: :object
    delegate :parent_refresh_token_hash, to: :object
    delegate :refresh_token_hash, to: :object
    delegate :session_handle, to: :object
    delegate :user_uuid, to: :object
    delegate :uuid, to: :object
    delegate :version, to: :object

    def active
      expiration_time > Time.zone.now
    end

    def aud
      audience
    end

    def exp
      expiration_time.to_i
    end

    def iat
      created_time.to_i
    end

    def id
      nil
    end

    def iss
      SignIn::Constants::AccessToken::ISSUER
    end

    def jti
      uuid
    end

    def last_regeneration_time
      object.last_regeneration_time.to_i
    end

    def sub
      user_uuid
    end

    def read_attribute_for_serialization(attr)
      send(attr)
    end

    def user_attributes
      object.user_attributes.presence
    end
  end
end
