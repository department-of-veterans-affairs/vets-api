# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  module V2
    class AppointmentForm < Common::Form
      attribute :kind, String
      attribute :status, String
      attribute :location_id, String
      attribute :clinic, String
      attribute :reason, String
      attribute :patient_icn, String
      attribute :slot, Hash
      attribute :contact, Hash
      attribute :service_type, String
      attribute :requested_periods, Array[Hash]

      def initialize(user, json_hash)
        @user = user
        super(json_hash)
      end
    end
  end
end
