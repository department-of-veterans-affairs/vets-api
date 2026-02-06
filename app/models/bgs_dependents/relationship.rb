# frozen_string_literal: true

module BGSDependents
  class Relationship < Base
    def initialize(proc_id)
      @proc_id = proc_id
    end

    def params_for_686c(participant_a_id, dependent)
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id_a: participant_a_id,
        vnp_ptcpnt_id_b: dependent[:vnp_participant_id],
        ptcpnt_rlnshp_type_nm: dependent[:participant_relationship_type_name],
        family_rlnshp_type_nm: dependent[:family_relationship_type_name],
        event_dt: format_date(dependent[:event_date]),
        begin_dt: format_date(dependent[:begin_date]),
        end_dt: format_date(dependent[:end_date]),
        mthly_support_from_vet_amt: dependent[:living_expenses_paid_amount],
        child_prevly_married_ind: dependent[:child_prevly_married_ind],
        dep_has_income_ind: dependent[:dep_has_income_ind]
      }.merge(marriage_params(dependent))
    end

    private

    def marriage_params(dependent)
      {
        marage_cntry_nm: dependent[:marriage_country],
        marage_state_cd: dependent[:marriage_state],
        marage_city_nm: dependent[:marriage_city],
        marage_trmntn_cntry_nm: dependent[:divorce_country],
        marage_trmntn_state_cd: dependent[:divorce_state],
        marage_trmntn_city_nm: dependent[:divorce_city],
        marage_trmntn_type_cd: dependent[:marriage_termination_type_code]
      }
    end
  end
end
