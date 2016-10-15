# frozen_string_literal: true
require 'virtus'

module Common
  module Exceptions
    # This class is used to construct the JSON API SPEC errors object used for exceptions
    class SerializableError
      include ActiveModel::Serialization
      extend ActiveModel::Naming
      include Virtus.model(nullify_blank: true)

      attribute :title, String
      attribute :detail, String
      attribute :id, Integer
      attribute :href, String
      attribute :code, String
      attribute :source, String
      # attribute :links, Array[String] # commenting this out for now as it complicates things
      attribute :status, String
      attribute :meta, String

      # return only those attributes that have non nil values
      def to_hash
        Hash[attribute_set.map { |a| [a.name, send(a.name)] unless send(a.name).nil? }.compact]
      end
    end
  end
end
