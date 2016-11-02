class AddGibctInstitutions < ActiveRecord::Migration
  def change
    create_table :institutions do |t|
      t.belongs_to :institution_type

      # Phyiscal Info
      t.string :facility_code, default: nil # String with null as no_data
      t.string :institution, default: nil # String with null as no_data
      t.string :city, default: nil # String with null as no_data
      t.string :state, default: nil # String with null as no_data
      t.string :zip, default: nil # String with null as no_data
      t.string :country, default: nil # String with null as no_data

      # School Metrics
      t.float :bah, default: nil # Float with "null" string values
      t.string :cross, default: nil # String with "null" string values
      t.string :ope, default: nil # String with null as no_data
      t.string :insturl, default: nil # String with null as no_data
      t.string :vet_tuition_policy_url, default: nil # String with null as no_data
      t.integer :pred_degree_awarded, default: nil # Integer with "null" string values
      t.integer :locale, default: nil # Integer with "null" string values
      t.integer :gibill, default: 0
      t.integer :undergrad_enrollment, default: nil # Integer with "null" string values
      t.boolean :yr, default: false
      t.boolean :student_veteran, default: false
      t.string :student_veteran_link, default: nil
      t.boolean :poe, default: false
      t.boolean :eight_keys, default: false
      t.boolean :dodmou, default: false
      t.boolean :sec_702, default: false
      t.string :vetsuccess_name, default: nil # String with "null" string values
      t.string :vetsuccess_email, default: nil # String with "null" string values
      t.string :credit_for_mil_training, default: nil # Boolean with null string values
      t.string :vet_poc, default: nil # Boolean with null string value
      t.string :student_vet_grp_ipeds, default: nil # Boolean with null string values
      t.string :soc_member, default: nil # Boolean with null string values
      t.string :va_highest_degree_offered, default: nil # string with "null" string values
      t.float :retention_rate_veteran_ba, default: nil #Float with "null" strings.
      t.float :retention_all_students_ba, default: nil #Float with "null" strings.
      t.float :retention_rate_veteran_otb, default: nil #Float with "null" strings.
      t.float :retention_all_students_otb, default: nil #Float with "null" strings.
      t.float :persistance_rate_veteran_ba, default: nil #Float with "null" strings.
      t.float :persistance_rate_veteran_otb, default: nil #Float with "null" strings.
      t.float :graduation_rate_veteran, default: nil #Float with "null" strings.
      t.float :graduation_rate_all_students, default: nil #Float with "null" strings.
      t.float :transfer_out_rate_veteran, default: nil #Float with "null" strings.
      t.float :transfer_out_rate_all_students, default: nil #Float with "null" strings.
      t.float :salary_all_students, default: nil #Float with "null" and other terms
      t.float :repayment_rate_all_students, default: nil #Float with "null" and other terms
      t.float :avg_stu_loan_debt, default: nil #Float with "null" and other terms
      t.string :calendar, default: nil # String with "null" string values
      t.float :tuition_in_state, default: nil #Float with "null" and other terms
      t.float :tuition_out_of_state, default: nil #Float with "null" and other terms
      t.float :books, default: nil #Float with "null" and other terms
      t.string :online_all, default: nil # Boolean with null string values
      t.float :p911_tuition_fees, default: 0.0
      t.integer :p911_recipients, default: 0
      t.float :p911_yellow_ribbon, default: 0.0
      t.integer :p911_yr_recipients, default: 0
      t.boolean :accredited, default: false
      t.string :accreditation_type, default: nil # String with "null" string values
      t.string :accreditation_status, default: nil # String with "null" string values
      t.string :caution_flag, default: nil # Boolean with null string values
      t.string :caution_flag_reason, default: nil # String with "null" string values

      # Complaint Data
      t.integer :complaints_facility_code, default: 0
      t.integer :complaints_financial_by_fac_code, default: 0
      t.integer :complaints_quality_by_fac_code, default: 0
      t.integer :complaints_refund_by_fac_code, default: 0
      t.integer :complaints_marketing_by_fac_code, default: 0
      t.integer :complaints_accreditation_by_fac_code, default: 0
      t.integer :complaints_degree_requirements_by_fac_code, default: 0
      t.integer :complaints_student_loans_by_fac_code, default: 0
      t.integer :complaints_grades_by_fac_code, default: 0
      t.integer :complaints_credit_transfer_by_fac_code, default: 0
      t.integer :complaints_credit_job_by_fac_code, default: 0
      t.integer :complaints_job_by_fac_code, default: 0
      t.integer :complaints_transcript_by_fac_code, default: 0
      t.integer :complaints_other_by_fac_code, default: 0
      t.integer :complaints_main_campus_roll_up, default: 0
      t.integer :complaints_financial_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_quality_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_refund_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_marketing_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_accreditation_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_degree_requirements_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_student_loans_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_grades_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_credit_transfer_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_jobs_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_transcript_by_ope_id_do_not_sum, default: 0
      t.integer :complaints_other_by_ope_id_do_not_sum, default: 0

      t.timestamps null: false

      t.index :facility_code
      t.index :institution_type_id
      t.index :institution
      t.index :city
      t.index :state
    end
  end
end
