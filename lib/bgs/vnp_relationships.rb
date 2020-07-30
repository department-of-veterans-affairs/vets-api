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

    # def create_relationship(participant_a_id, dependent)
    #   with_multiple_attempts_enabled do
    #     service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(
    #       {
    #         vnp_proc_id: @proc_id,
    #         vnp_ptcpnt_id_a: participant_a_id,
    #         vnp_ptcpnt_id_b: dependent[:vnp_participant_id],
    #         ptcpnt_rlnshp_type_nm: dependent[:participant_relationship_type_name],
    #         family_rlnshp_type_nm: dependent[:family_relationship_type_name],
    #         event_dt: format_date(dependent[:event_date]),
    #         begin_dt: format_date(dependent[:begin_date]),
    #         end_dt: format_date(dependent[:end_date]),
    #         marage_state_cd: dependent[:marriage_state],
    #         marage_city_nm: dependent[:marriage_city],
    #         marage_trmntn_state_cd: dependent[:divorce_state],
    #         marage_trmntn_city_nm: dependent[:divorce_city],
    #         marage_trmntn_type_cd: dependent[:marriage_termination_type_code],
    #         mthly_support_from_vet_amt: dependent[:living_expenses_paid_amount]
    #       }.merge(bgs_auth)
    #     )
    #   end
    # end

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
