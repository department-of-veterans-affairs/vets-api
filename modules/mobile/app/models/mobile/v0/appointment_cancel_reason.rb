# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AppointmentCancelReason < Common::Resource
      
      UNABLE_TO_KEEP_APPT = '5'
      VALID_CANCEL_CODES = Types::String.enum('4', '5', '6')

      attribute :number, Types::String
      attribute :text, Types::String
      attribute :type, Types::String
      attribute :inactive, Types::Bool
    end
  end
end
