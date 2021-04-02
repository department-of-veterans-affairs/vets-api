# frozen_string_literal: true

module OpenidAuth
  class ValidationSerializerV2 < ActiveModel::Serializer
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
               :act,
               :launch

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

    delegate :act, to: :object

    delegate :launch, to: :object
  end
end
