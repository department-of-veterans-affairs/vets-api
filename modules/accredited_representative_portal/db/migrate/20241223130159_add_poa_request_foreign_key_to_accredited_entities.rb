class AddPoaRequestForeignKeyToAccreditedEntities < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :ar_power_of_attorney_requests, :accredited_individuals, validate: false
    add_foreign_key :ar_power_of_attorney_requests, :accredited_organizations, validate: false
  end
end
