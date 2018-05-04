# frozen_string_literal: true

require 'common/models/base'
require 'common/models/attribute_types/iso8601_time'

module Vet360
  module Models
    class Base
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      SOURCE_SYSTEM = 'VETSGOV'
      DEFAULT_ATTRS = %i[effective_start_date source_date vet360_id].freeze

      # Creates an instance of this class, and simultaneously sets default values
      # for the DEFAULT_ATTRS.
      #
      # If the instance does not have all of those DEFAULT_ATTRS present, it raises an exception.
      #
      # @param user [User] The user associated with the transaction
      # @param params [Hash] A hash of key/value pairs to build the instance with
      # @return [Vet360::Models::Base] A Vet360::Models::Base instance, be it Email, Address, etc.
      #
      def self.with_defaults(user, params)
        instance = new(params)
        now      = Time.zone.now.iso8601

        if instance.default_attrs_present?
          instance.tap do |record|
            record.attributes = {
              effective_start_date: now,
              source_date: now,
              vet360_id: user.vet360_id
            }
          end
        else
          raise "Model must have these attributes: #{DEFAULT_ATTRS}"
        end
      end

      # Checks if the instance does, or does not, have the DEFAULT_ATTRS.
      # It is not checking for the presence of values on those attributes.  It is confirming
      # if the instance has those attributes, at all.
      #
      # @return [Boolean] true or false
      #
      def default_attrs_present?
        attributes.keys & DEFAULT_ATTRS == DEFAULT_ATTRS
      end
    end
  end
end
