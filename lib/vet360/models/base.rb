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

      def self.with_defaults(user, params)
        instance = new(params)
        now      = Time.now.iso8601

        return unless instance.default_attrs_present?

        instance.tap do |record|
          record.attributes = {
            effective_start_date: now,
            source_date: now,
            vet360_id: user.vet360_id
          }
        end
      end

      def default_attrs_present?
        attributes.keys & DEFAULT_ATTRS == DEFAULT_ATTRS
      end
    end
  end
end
