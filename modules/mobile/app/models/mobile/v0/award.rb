# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Award < Common::Resource
      attribute :id, Types::String
      attribute :aportn_recip_id, Types::Integer
      attribute :award_amt, Types::Decimal
      attribute :award_cmpsit_id, Types::String
      attribute :award_curnt_status_cd, Types::String
      attribute :award_event_id, Types::String
      attribute :award_line_report_id, Types::String
      attribute :award_line_type_cd, Types::String
      attribute :award_stn_nbr, Types::String
      attribute :award_type_cd, Types::String
      attribute :combnd_degree_pct, Types::String
      attribute :dep_hlpls_this_nbr, Types::Integer
      attribute :dep_hlpls_total_nbr, Types::Integer
      attribute :dep_school_this_nbr, Types::Integer
      attribute :dep_school_total_nbr, Types::Integer
      attribute :dep_this_nbr, Types::Integer
      attribute :dep_total_nbr, Types::Integer
      attribute :efctv_dt, Types::DateTime
      attribute :entlmt_type_cd, Types::String
      attribute :file_nbr, Types::Integer
      attribute :future_efctv_dt, Types::DateTime
      attribute :gross_adjsmt_amt, Types::Decimal
      attribute :gross_amt, Types::Decimal
      attribute :ivap_amt, Types::Decimal
      attribute :jrn_dt, Types::DateTime
      attribute :jrn_lctn_id, Types::String
      attribute :jrn_obj_id, Types::String
      attribute :jrn_status_type_cd, Types::String
      attribute :jrn_user_id, Types::String
      attribute :net_amt, Types::Decimal
      attribute :payee_type_cd, Types::String
      attribute :prior_efctv_dt, Types::DateTime
      attribute :ptcpnt_bene_id, Types::String
      attribute :ptcpnt_vet_id, Types::String
      attribute :reason_one_txt, Types::String
      attribute :spouse_txt, Types::String
    end
  end
end
