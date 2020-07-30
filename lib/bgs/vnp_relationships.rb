# frozen_string_literal: true

module BGS
  class VnpRelationships
    def initialize(proc_id:, veteran:, dependents:, user:)
      @user = user
      @veteran = veteran
      @proc_id = proc_id
      @dependents = dependents
    end

    def create
      spouse_marriages, vet_dependents = @dependents.partition do |dependent|
        dependent[:type] == 'spouse_marriage_history'
      end

      spouse = @dependents.find { |dependent| dependent[:type] == 'spouse' }

      spouse_marriages.each do |dependent|
        bgs_service.create_relationship(
          vnp_relationship.params_for_686c(spouse[:vnp_participant_id], dependent)
        )
      end

      vet_dependents.each do |dependent|
        bgs_service.create_relationship(
          vnp_relationship.params_for_686c(@veteran[:vnp_participant_id], dependent)
        )
      end
    end

    private

    def bgs_service
      BGS::Service.new(@user)
    end

    def vnp_relationship
      BGSDependents::Relationship.new(
        @proc_id
      )
    end
  end
end
