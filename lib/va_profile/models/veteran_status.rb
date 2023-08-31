# frozen_string_literal: true

require_relative 'base'
# need this line?
require 'va_profile/concerns/defaultable'

module VAProfile
  module Models
    class VeteranStatus < Base
      include VAProfile::Concerns::Defaultable  # need this?

      attribute :title_38_status_code, String

      # Converts an instance of the VeteranStatus model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def self.in_json
        {
          bios: [
            {
              bioPath: 'militaryPerson.militarySummary'
            }
          ]
        }.to_json
      end
    end
  end
end
