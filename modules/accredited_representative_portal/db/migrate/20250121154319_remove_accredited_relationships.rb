class RemoveAccreditedRelationships < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_foreign_key :ar_power_of_attorney_requests, :accredited_individuals

      remove_reference :ar_power_of_attorney_requests, :accredited_individual,
                       index: { algorithm: :concurrently }
    end
  end
end
