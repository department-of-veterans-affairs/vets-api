class ValidateValidateAddNotNullConstraintToVetRepTable < ActiveRecord::Migration[6.1]
  def change
    validate_check_constraint :veteran_representatives, name: "veteran_representatives_representative_id_null"
  end
end