class AddPoaRequestReferencesRepresentatives < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference(
      :ar_power_of_attorney_requests,
      :power_of_attorney_holder,
      polymorphic: true,
      type: :uuid,
      null: false,
      index: { algorithm: :concurrently } 
    )

    add_reference(
      :ar_power_of_attorney_requests,
      :accredited_individual,
      type: :uuid,
      null: false,
      index: { algorithm: :concurrently } 
    )
  end
end
