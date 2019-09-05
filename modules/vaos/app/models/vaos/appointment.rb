# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class Appointment < Common::Resource
    ContactTimes = Types::Strict::String.enum('morning', 'afternoon', 'evening')
    Statuses = Types::Strict::String.enum('pending', 'booked')

    attribute :id, Types::String
    attribute :facility_id, Types::String
    attribute :facility, Types.Constructor(VAOS::Facility)
    attribute :date_time, Types::DateTime
    attribute :reason, Types::String
    attribute :type, Types::String
    attribute :contact_number, Types::String
    attribute :preferred_contact_time, ContactTimes
    attribute :status, Statuses
    attribute :pact_team, Types.Constructor(VAOS::PactTeam)
  end
end
