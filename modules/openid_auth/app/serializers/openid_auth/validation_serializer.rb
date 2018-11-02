# frozen_string_literal: true

module OpenidAuth
    class ValidationSerializer < ActiveModel::Serializer
      alias :read_attribute_for_serialization :send
      
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

      def ver
        object.ver
      end

      def jti
        object.jti
      end

      def iss
        object.iss
      end

      def aud
        object.aud
      end

      def iat
        object.iat
      end

      def exp
        object.exp
      end

      def cid
        object.cid
      end

      def uid
        object.uid
      end

      def scp
        object.scp
      end

      def sub 
        object.sub
      end

      def va_identifiers
        {}
      end
    end
  end