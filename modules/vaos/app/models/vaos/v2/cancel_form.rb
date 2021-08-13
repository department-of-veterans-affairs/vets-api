# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/exceptions'

module VAOS
  module V2
    class CancelForm < Common::Form
      attribute :status, String
      attribute :cancellation_reason, String

      validates :status, :cancellation_reason, presence: true
      validates :status, inclusion: { in: %w[cancelled] }

      def params
        raise Common::Exceptions::ValidationErrors, self unless valid?

        attributes.compact
      end
    end
  end
end
