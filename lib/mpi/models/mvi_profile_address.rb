# frozen_string_literal: true

module MPI
  module Models
    class MviProfileAddress < ActiveModel::Type::Value
      include ActiveModel::API
      include ActiveModel::Attributes
      include ActiveModel::Serializers::JSON

      attribute :street, :string
      attribute :street2, :string
      attribute :city, :string
      attribute :state, :string
      attribute :postal_code, :string
      attribute :country, :string

      def type = :mvi_profile_address

      def [](key)
        attributes[key.to_s]
      end

      def to_h
        attributes.symbolize_keys
      end
    end

    ActiveModel::Type.register :mvi_profile_address, MviProfileAddress
  end
end
