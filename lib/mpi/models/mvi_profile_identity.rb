# frozen_string_literal: true

require 'common/models/attribute_types/date_time_string'
require_relative 'mvi_profile_address'

module MPI
  module Models
    module MviProfileIdentity
      include Virtus.module

      attribute :given_names, Array[String]
      attribute :family_name, String
      attribute :preferred_names, Array[String]
      attribute :suffix, String
      attribute :gender, String
      attribute :birth_date, Common::DateTimeString
      attribute :deceased_date, Common::DateTimeString
      attribute :ssn, String
      attribute :address, MviProfileAddress
      attribute :home_phone, String
      attribute :person_types, Array[String]

      def normalized_suffix
        case @suffix
        when /jr\.?/i
          'Jr.'
        when /sr\.?/i
          'Sr.'
        when /iii/i
          'III'
        when /ii/i
          'II'
        when /iv/i
          'IV'
        end
      end
    end
  end
end
