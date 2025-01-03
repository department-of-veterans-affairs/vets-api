# frozen_string_literal: true

require 'virtus'
require 'active_model'

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
      attribute :links, Array[String]
      attribute :status, String
      attribute :meta, String

      def detail
        super || title
      end

      # return only those attributes that have non nil values
      def to_hash
        attribute_set.map { |a| [a.name, send(a.name)] if send(a.name).present? }.compact.to_h
      end
    end
  end
end
