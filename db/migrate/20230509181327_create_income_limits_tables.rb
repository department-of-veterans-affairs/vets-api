class CreateIncomeLimitsTables < ActiveRecord::Migration[6.1]
  def change
    create_table :std_counties do |t|
      t.string :name, null: false
      t.integer :county_number, null: false
      t.string :description, null: false
      t.integer :state_id, null: false
      t.integer :version, null: false
      t.datetime :created, null: false
      t.datetime :updated
      t.string :created_by
      t.string :updated_by
    end

    create_table :gmt_thresholds do |t|
      t.integer :effective_year, null: false
      t.string :state_name, null: false
      t.string :county_name, null: false
      t.integer :fips, null: false
      t.integer :trhd1, null: false
      t.integer :trhd2, null: false
      t.integer :trhd3, null: false
      t.integer :trhd4, null: false
      t.integer :trhd5, null: false
      t.integer :trhd6, null: false
      t.integer :trhd7, null: false
      t.integer :trhd8, null: false
      t.integer :msa, null: false
      t.string :msa_name
      t.integer :version, null: false
      t.datetime :created, null: false
      t.datetime :updated
      t.string :created_by
      t.string :updated_by
    end

    create_table :std_incomethresholds do |t|
      t.integer :income_threshold_year, null: false
      t.integer :exempt_amount, null: false
      t.integer :medical_expense_deductible, null: false
      t.integer :child_income_exclusion, null: false
      t.integer :dependent, null: false
      t.integer :add_dependent_threshold, null: false
      t.integer :property_threshold, null: false
      t.integer :pension_threshold
      t.integer :pension_1_dependent
      t.integer :add_dependent_pension
      t.integer :ninety_day_hospital_copay
      t.integer :add_ninety_day_hospital_copay
      t.integer :outpatient_basic_care_copay
      t.integer :outpatient_specialty_copay
      t.datetime :threshold_effective_date
      t.integer :aid_and_attendance_threshold
      t.integer :outpatient_preventive_copay
      t.integer :medication_copay
      t.integer :medication_copay_annual_cap
      t.integer :ltc_inpatient_copay
      t.integer :ltc_outpatient_copay
      t.integer :ltc_domiciliary_copay
      t.integer :inpatient_per_diem
      t.string :description
      t.integer :version, null: false
      t.datetime :created, null: false
      t.datetime :updated
      t.string :created_by
      t.string :updated_by
    end

    create_table :std_states do |t|
      t.string :name, null: false
      t.string :postal_name, null: false
      t.integer :fips_code, null: false
      t.integer :country_id, null: false
      t.integer :version, null: false
      t.datetime :created, null: false
      t.datetime :updated
      t.string :created_by
      t.string :updated_by
    end

    create_table :std_zipcodes do |t|
      t.integer :zip_code, null: false
      t.integer :zip_classification_id
      t.integer :preferred_zip_place_id
      t.integer :state_id, null: false
      t.integer :county_number, null: false
      t.integer :version, null: false
      t.datetime :created, null: false
      t.datetime :updated
      t.string :created_by
      t.string :updated_by
    end
  end
end