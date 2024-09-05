# frozen_string_literal: true

module Mobile
  module V0
    class DependentSerializer
      include JSONAPI::Serializer

      set_type :dependents
      attributes :award_indicator,
                 :date_of_birth,
                 :email_address,
                 :first_name,
                 :last_name,
                 :middle_name,
                 :proof_of_dependency,
                 :ptcpnt_id,
                 :related_to_vet,
                 :relationship,
                 :veteran_indicator
    end
  end
end
