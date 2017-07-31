# frozen_string_literal: true
module Swagger
  module Schemas
    module Gibct
      class Institutions
        include Swagger::Blocks

        swagger_schema :GibctInstitutionsAutocomplete do
          key :required, [:data, :meta, :links]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              property :id, type: :integer
              property :value, type: :string
              property :label, type: :string
            end
          end

          property :meta, '$ref': :GibctInstitutionsAutocompleteMeta
          property :links, '$ref': :GibctInstitutionsSelfLinks
        end

        swagger_schema :GibctInstitutionsSearch do
          key :required, [:data, :meta, :links]

          property :data, type: :array, maxItems: 10, uniqueItems: true do
            items do
              key :type, :object
              key :'$ref', :GibctInstitutionBase
            end
          end

          property :meta, '$ref': :GibctInstitutionsSearchMeta
          property :links, '$ref': :GibctInstitutionsSearchLinks
        end

        swagger_schema :GibctInstitution do
          key :type, :object
          key :required, [:data, :meta]

          property :data, type: :object do
            key :'$ref', :GibctInstitutionBase
            property :flight, type: :boolean
            property :correspondence, type: :boolean
            property :cross, type: [:null, :string]
            property :ope, type: [:null, :string]
            property :ope6, type: [:null, :string]
            property :undergrad_enrollment, type: [:null, :integer]
            property :student_veteran, type: :boolean
            property :student_veteran_link, type: [:null, :string]
            property :dodmou, type: :boolean
            property :sec_702, type: [:null, :boolean]
            property :vet_success_name, type: [:null, :string]
            property :vet_success_email, type: [:null, :string]
            property :credit_for_mil_training, type: [:null, :boolean]
            property :vet_poc, type: [:null, :boolean]
            property :student_vet_grp_ipeds, type: [:null, :boolean]
            property :soc_member, type: [:null, :boolean]
            property :retention_rate_veteran_ba, type: [:null, :number]
            property :retention_all_students_ba, type: [:null, :number]
            property :retention_rate_veteran_otb, type: [:null, :number]
            property :retention_all_students_otb, type: [:null, :number]
            property :persistance_rate_veteran_ba, type: [:null, :number]
            property :persistance_rate_veteran_otb, type: [:null, :number]
            property :graduation_rate_veteran, type: [:null, :number]
            property :graduation_rate_all_students, type: [:null, :number]
            property :transfer_out_rate_veteran, type: [:null, :number]
            property :transfer_out_rate_all_students, type: [:null, :number]
            property :salary_all_students, type: [:null, :number]
            property :repayment_rate_all_students, type: [:null, :number]
            property :avg_stu_loan_debt, type: [:null, :number]
            property :calendar, type: [:null, :string]
            property :online_all, type: [:null, :string]
            property :p911_tuition_fees, type: :number
            property :p911_recipients, type: :integer
            property :p911_yellow_ribbon, type: :number
            property :p911_yr_recipients, type: :integer
            property :accredited, type: :boolean
            property :accreditation_type, type: [:null, :string]
            property :accreditation_status, type: [:null, :string]
            property :complaints, type: :object do
              property :facility_code, type: :integer
              property :financial_by_fac_code, type: :integer
              property :quality_by_fac_code, type: :integer
              property :refund_by_fac_code, type: :integer
              property :marketing_by_fac_code, type: :integer
              property :accreditation_by_fac_code, type: :integer
              property :degree_requirements_by_fac_code, type: :integer
              property :student_loans_by_fac_code, type: :integer
              property :grades_by_fac_code, type: :integer
              property :credit_transfer_by_fac_code, type: :integer
              property :credit_job_by_fac_code, type: :integer
              property :job_by_fac_code, type: :integer
              property :transcript_by_fac_code, type: :integer
              property :other_by_fac_code, type: :integer
              property :main_campus_roll_up, type: :integer
              property :financial_by_ope_id_do_not_sum, type: :integer
              property :quality_by_ope_id_do_not_sum, type: :integer
              property :refund_by_ope_id_do_not_sum, type: :integer
              property :marketing_by_ope_id_do_not_sum, type: :integer
              property :accreditation_by_ope_id_do_not_sum, type: :integer
              property :degree_requirements_by_ope_id_do_not_sum, type: :integer
              property :student_loans_by_ope_id_do_not_sum, type: :integer
              property :grades_by_ope_id_do_not_sum, type: :integer
              property :credit_transfer_by_ope_id_do_not_sum, type: :integer
              property :jobs_by_ope_id_do_not_sum, type: :integer
              property :transcript_by_ope_id_do_not_sum, type: :integer
              property :other_by_ope_id_do_not_sum, type: :integer
            end
          end

          property :meta, '$ref': :GibctInstitutionsShowMeta
        end

        swagger_schema :GibctInstitutionsAutocompleteMeta do
          key :type, :object
          key :required, [:version, :term]

          property :version, type: :integer
          property :term, type: :string
        end

        swagger_schema :GibctInstitutionsSearchMeta do
          key :type, :object
          key :required, [:version, :count]

          property :version, type: :integer
          property :count, type: :integer
        end

        swagger_schema :GibctInstitutionsShowMeta do
          key :type, :object
          key :required, [:version]

          property :version, type: :integer
        end

        swagger_schema :GibctInstitutionsSearchLinks do
          key :type, :object
          key :required, [:self, :first, :prev, :next, :last]

          property :self, type: :string
          property :first, type: :string
          property :prev, type: [:null, :string]
          property :next, type: [:null, :string]
          property :last, type: :string
        end

        swagger_schema :GibctInstitutionBase do
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :name, type: :string
            property :facility_code, type: :string
            property :type, type: :string,
                            enum: ['ojt', 'private', 'foreign', 'correspondence', 'flight', 'for profit', 'public']
            property :city, type: [:null, :string]
            property :state, type: [:null, :string]
            property :zip, type: [:null, :string]
            property :country, type: [:null, :string]
            property :highest_degree, type: [:null, :integer]
            property :locale_type, type: [:null, :string]
            property :student_count, type: [:null, :integer]
            property :caution_flag, type: :boolean
            property :caution_flag_reason, type: [:null, :string]
            property :created_at, type: :string
            property :updated_at, type: :string
            property :bah, type: [:null, :number]
            property :tuition_in_state, type: [:null, :number]
            property :tuition_out_of_state, type: [:null, :number]
            property :books, type: [:null, :number]
            property :student_veteran, type: :boolean
            property :yr, type: :boolean
            property :poe, type: :boolean
            property :eight_keys, type: :boolean
            property :links, '$ref': :GibctInstitutionsSelfLinks
          end
        end

        swagger_schema :GibctInstitutionsSelfLinks do
          key :type, :object
          key :required, [:self]

          property :self, type: :string
        end
      end
    end
  end
end
