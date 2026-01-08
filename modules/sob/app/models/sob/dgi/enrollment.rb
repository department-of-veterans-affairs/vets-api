# frozen_string_literal: true

module SOB
  module DGI
    class Enrollment
      include Vets::Model

      # Facility code of most recent enrollment required by form 22-10203 in order to send SCO email
      # Additional enrollment data available from DGI response but not currently required
      attribute :facility_code, String
    end
  end
end
