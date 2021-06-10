# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/exceptions'

module VAOS
  module V2
    class AppointmentForm < Common::Form
      attribute :kind, String
      attribute :status, String
      attribute :location_id, String
      attribute :clinic, String
      attribute :reason, String
      attribute :slot, Hash
      attribute :contact, Hash
      attribute :service_type, String
      attribute :requested_periods, Array[Hash]

      def initialize(user, json_hash)
        @user = user
        super(json_hash)
      end

      def params
        raise Common::Exceptions::ValidationErrors, self unless valid?

        attributes.compact
      end
    end
  end
end
