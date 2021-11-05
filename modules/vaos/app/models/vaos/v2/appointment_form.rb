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
      attribute :practitioner_ids, Array[Hash]
      attribute :clinic, String
      attribute :reason, String
      attribute :slot, Hash
      attribute :contact, Hash
      attribute :service_type, String
      attribute :requested_periods, Array[Hash]
      attribute :preferred_language, String
      attribute :minutes_duration, Integer
      attribute :reason_code, Hash
      attribute :priority, Integer
      attribute :practitioners, Array[Hash]
      attribute :preferred_times_for_phone_call, Array[String]
      attribute :preferred_location, Hash
      attribute :cancellation_reason, Hash
      attribute :cancelation_reason, Hash
      attribute :description, String
      attribute :comment, String
      attribute :preferred_language, String
      attribute :cancellable, Boolean
      attribute :patient_instruction, String
      attribute :telehealth, Hash
      attribute :extension, Hash

      def initialize(user, json_hash)
        @user = user
        super(json_hash)
      end

      def params
        raise Common::Exceptions::ValidationErrors, self unless valid?

        attributes.merge(patient_icn: @user.icn, slot: slot.empty? ? nil : slot).compact
      end
    end
  end
end
