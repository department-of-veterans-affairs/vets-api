class DropCredentialAdoptionEmailRecord < ActiveRecord::Migration[7.0]
  def up
    drop_table :credential_adoption_email_records
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
