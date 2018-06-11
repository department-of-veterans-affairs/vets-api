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

      validate :past_date?

      private

      def past_date?
        errors.add(:effective_end_date, "must be in the past") if effective_end_date && !effective_end_date.past?
      end

    end
  end
end
