# frozen_string_literal: true

module Mobile
  module V0
    class AwardSerializer < ActiveModel::Serializer
      attribute(:id) { object.aportn_recip_id }

      attribute :aportn_recip_id
      attribute :award_amt
      attribute :award_cmpsit_id
      attribute :award_curnt_status_cd
      attribute :award_event_id
      attribute :award_line_report_id
      attribute :award_line_type_cd
      attribute :award_stn_nbr
      attribute :award_type_cd
      attribute :combnd_degree_pct
      attribute :dep_hlpls_this_nbr
      attribute :dep_hlpls_total_nbr
      attribute :dep_school_this_nbr
      attribute :dep_school_total_nbr
      attribute :dep_this_nbr
      attribute :dep_total_nbr
      attribute :efctv_dt
      attribute :entlmt_type_cd
      attribute :file_nbr
      attribute :future_efctv_dt
      attribute :gross_adjsmt_amt
      attribute :gross_amt
      attribute :ivap_amt
      attribute :jrn_dt
      attribute :jrn_lctn_id
      attribute :jrn_obj_id
      attribute :jrn_status_type_cd
      attribute :jrn_user_id
      attribute :net_amt
      attribute :payee_type_cd
      attribute :prior_efctv_dt
      attribute :ptcpnt_bene_id
      attribute :ptcpnt_vet_id
      attribute :reason_one_txt
      attribute :spouse_txt
      attribute :veteran_id
      attribute :is_eligible_for_pension
      attribute :is_in_receipt_of_pension
      attribute :net_worth_limit
    end
  end
end
