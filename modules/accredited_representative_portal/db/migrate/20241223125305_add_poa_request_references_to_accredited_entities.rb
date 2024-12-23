class AddPoaRequestReferencesToAccreditedEntities < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference(
      :ar_power_of_attorney_requests,
      :accredited_individual,
      type: :uuid,
      null: false,
      index: { algorithm: :concurrently }
    )

    add_reference(
      :ar_power_of_attorney_requests,
      :accredited_organization,
      type: :uuid,
      null: true,
      index: { algorithm: :concurrently }
    )
  end
end
