# frozen_string_literal: true

require_relative 'base'

module VAProfile
  module Models
    class MilitaryOccupation < Base
      attribute :service_segment_sequence, Integer
      attribute :occupation_segment_sequence, Integer
      attribute :occupation_type_code, String
      attribute :occupation_type_text, String
      attribute :dod_provided_code, String
      attribute :dod_occupation_code, String
      attribute :dod_occupation_text, String
      attribute :service_provided_code, String
      attribute :service_specific_occupation_code, String
      attribute :service_specific_occupation_text, String
      attribute :effective_date, String
    end
  end
end
