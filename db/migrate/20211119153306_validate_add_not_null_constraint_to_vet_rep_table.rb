class ValidateAddNotNullConstraintToVetRepTable < ActiveRecord::Migration[6.1]
  def change
    add_check_constraint :veteran_representatives, "representative_id IS NOT NULL", name: "veteran_representatives_representative_id_null", validate: false
  end
end