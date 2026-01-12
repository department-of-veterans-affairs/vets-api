# frozen_string_literal: true

module SOB
  module DGI
    class Enrollment
      include Vets::Model

      # Facility code and begin date required by form 22-10203 in order to send SCO email
      # Additional enrollment data available from DGI response but not currently required
      attribute :facility_code, String
      attribute :begin_date, DateTime
    end
  end
end
