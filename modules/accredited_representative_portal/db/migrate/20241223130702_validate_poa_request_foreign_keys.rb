class ValidatePoaRequestForeignKeys < ActiveRecord::Migration[7.1]
  def change
    validate_foreign_key :ar_power_of_attorney_requests, :accredited_individuals
    validate_foreign_key :ar_power_of_attorney_requests, :accredited_organizations
  end
end
