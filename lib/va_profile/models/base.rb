# frozen_string_literal: true

require 'common/models/base'
require 'common/models/attribute_types/iso8601_time'

module VAProfile
  module Models
    class Base
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include Virtus.model(nullify_blank: true)

      SOURCE_SYSTEM = 'VETSGOV'

      validate :past_date?

      private

      def past_date?
        if effective_end_date.present? && (effective_end_date > Time.zone.now)
          errors.add(:effective_end_date, 'must be in the past')
        end
      end
    end
  end
end
