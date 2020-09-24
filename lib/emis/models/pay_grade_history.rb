# frozen_string_literal: true

module EMIS
  module Models
    class PayGradeHistory
      include Virtus.model

      attribute :personnel_organization_code, String
      attribute :personnel_category_type_code, String
      attribute :personnel_segment_identifier, String
      attribute :pay_plan_code, String
      attribute :pay_grade_code, String
      attribute :service_rank_name_code, String
      attribute :service_rank_name_txt, String
      attribute :pay_grade_date, Date
    end
  end
end
