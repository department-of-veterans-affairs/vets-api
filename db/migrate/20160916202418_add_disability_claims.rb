class AddDisabilityClaims < ActiveRecord::Migration
  def change
    create_table(:disability_claims) do |t|
      t.integer(:evss_id, null: false, unique: true)
      t.json(:data, null: false)
      t.timestamps(null: false)
    end
  end
end
