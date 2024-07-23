# frozen_string_literal: true

module Mobile
  module V0
    class AwardSerializer
      include JSONAPI::Serializer

      set_type :awards
      attributes :id,
                 :aportn_recip_id,
                 :award_amt,
                 :award_cmpsit_id,
                 :award_curnt_status_cd,
                 :award_event_id,
                 :award_line_report_id,
                 :award_line_type_cd,
                 :award_stn_nbr,
                 :award_type_cd,
                 :combnd_degree_pct,
                 :dep_hlpls_this_nbr,
                 :dep_hlpls_total_nbr,
                 :dep_school_this_nbr,
                 :dep_school_total_nbr,
                 :dep_this_nbr,
                 :dep_total_nbr,
                 :efctv_dt,
                 :entlmt_type_cd,
                 :file_nbr,
                 :future_efctv_dt,
                 :gross_adjsmt_amt,
                 :gross_amt,
                 :ivap_amt,
                 :jrn_dt,
                 :jrn_lctn_id,
                 :jrn_obj_id,
                 :jrn_status_type_cd,
                 :jrn_user_id,
                 :net_amt,
                 :payee_type_cd,
                 :prior_efctv_dt,
                 :ptcpnt_bene_id,
                 :ptcpnt_vet_id,
                 :reason_one_txt,
                 :spouse_txt
    end
  end
end
