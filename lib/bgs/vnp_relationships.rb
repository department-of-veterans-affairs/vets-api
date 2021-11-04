# frozen_string_literal: true

require_relative 'service'

module BGS
  class VnpRelationships
    def initialize(proc_id:, veteran:, step_children:, dependents:, user:)
      @user = user
      @veteran = veteran
      @proc_id = proc_id
      @step_children = step_children
      @dependents = dependents
    end

    def create_all
      spouse_marriages, vet_dependents = @dependents.partition do |dependent|
        dependent[:type] == 'spouse_marriage_history'
      end

      spouse = @dependents.find { |dependent| dependent[:type] == 'spouse' }

      send_step_children_relationships if @step_children.present?
      send_spouse_marriage_history_relationships(spouse, spouse_marriages)
      send_vet_dependent_relationships(vet_dependents)
    end

    private

    def send_step_children_relationships
      step_children, step_children_parents = @step_children.partition do |dependent|
        dependent[:type] == 'stepchild'
      end

      step_children.each do |step_child|
        bgs_service.create_relationship(
          vnp_relationship.params_for_686c(step_child[:guardian_particpant_id], step_child)
        )
      end

      step_children_parents.each do |step_child_parent|
        bgs_service.create_relationship(
          vnp_relationship.params_for_686c(@veteran[:vnp_participant_id], step_child_parent)
        )
      end
    end

    def send_vet_dependent_relationships(vet_dependents)
      vet_dependents.each do |dependent|
        bgs_service.create_relationship(
          vnp_relationship.params_for_686c(@veteran[:vnp_participant_id], dependent)
        )
      end
    end

    def send_spouse_marriage_history_relationships(spouse, spouse_marriages)
      spouse_marriages.each do |dependent|
        bgs_service.create_relationship(
          vnp_relationship.params_for_686c(spouse[:vnp_participant_id], dependent)
        )
      end
    end

    def bgs_service
      BGS::Service.new(@user)
    end

    def vnp_relationship
      BGSDependents::Relationship.new(@proc_id)
    end
  end
end
