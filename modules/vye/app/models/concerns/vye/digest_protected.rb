# frozen_string_literal: true

module Vye
  module DigestProtected
    extend ActiveSupport::Concern

    class_methods do
      # Use this method to specify the digested attribute.
      def digest_attribute(name)
        # Define a getter that will display the digested attribute
        digested_name = format('%<name>s_digest', name:)
        define_method(digested_name) do
          return if self[digested_name].blank?

          self[digested_name].unpack('H8H4H4H4H12').join('-').upcase
        end

        # Define a setter that will digest the attribute
        writer = format('%<name>s=', name:)
        define_method(writer) do |value|
          return if value.blank?

          self[digested_name] = gen_digest(value)
        end

        # Define a class method for finding records by the digested value of the specified attribute
        finder = format('find_from_digested_%<name>s', name:)
        define_singleton_method(finder) do |value|
          find_by(digested_name => gen_digest(value))
        end
      end
    end

    included do
      def gen_digest(value)
        value&.then { |v| OpenSSL::KDF.scrypt(v, **scrypt_config) }
      end

      private

      def scrypt_config
        Vye
          .settings
          &.scrypt
          &.to_h
          &.slice(:salt, :N, :r, :p, :length)
          &.freeze
      end
    end
  end
end
