# frozen_string_literal: true

module OpenidAuth
  class ValidationSerializer < ActiveModel::Serializer
    alias read_attribute_for_serialization send

    type 'validated_token'

    def id
      object.jti
    end

    attributes :ver,
               :jti,
               :iss,
               :aud,
               :iat,
               :exp,
               :cid,
               :uid,
               :scp,
               :sub,
               :va_identifiers

    delegate :ver, to: :object

    delegate :jti, to: :object

    delegate :iss, to: :object

    delegate :aud, to: :object

    delegate :iat, to: :object

    delegate :exp, to: :object

    delegate :cid, to: :object

    delegate :uid, to: :object

    delegate :scp, to: :object

    delegate :sub, to: :object

    delegate :va_identifiers, to: :object
  end
end
