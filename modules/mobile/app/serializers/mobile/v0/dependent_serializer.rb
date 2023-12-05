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

      def initialize(dependents)
        resource = dependents.map do |dependent|
          DependentStruct.new(SecureRandom.uuid,
                              dependent[:award_indicator],
                              dependent[:date_of_birth],
                              dependent[:email_address],
                              dependent[:first_name],
                              dependent[:last_name],
                              dependent[:middle_name],
                              dependent[:proof_of_dependency],
                              dependent[:ptcpnt_id],
                              dependent[:related_to_vet],
                              dependent[:relationship],
                              dependent[:veteran_indicator])
        end

        super(resource)
      end
    end

    DependentStruct = Struct.new(:id,
                                 :award_indicator,
                                 :date_of_birth,
                                 :email_address,
                                 :first_name,
                                 :last_name,
                                 :middle_name,
                                 :proof_of_dependency,
                                 :ptcpnt_id,
                                 :related_to_vet,
                                 :relationship,
                                 :veteran_indicator)
  end
end
