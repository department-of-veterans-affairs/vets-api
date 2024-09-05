# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/exceptions'

module VAOS
  module V2
    class UpdateAppointmentForm < Common::Form
      STATUS_OPTIONS = %w[proposed pending booked arrived noshow fulfilled cancelled].freeze

      attribute :status, String

      validates :status, presence: true
      validates :status, inclusion: { in: STATUS_OPTIONS }

      def params
        raise Common::Exceptions::ValidationErrors, self unless valid?

        attributes.compact
      end

      def json_patch_op
        raise Common::Exceptions::ValidationErrors, self unless valid?

        {
          op: 'replace',
          path: '/status',
          value: status
        }
      end
    end
  end
end
