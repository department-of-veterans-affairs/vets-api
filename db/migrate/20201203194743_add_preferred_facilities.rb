class AddPreferredFacilities < ActiveRecord::Migration[6.0]
  def change
    create_table(:preferred_facilities) do |t|
      t.string(:facility_code, null: false)
      t.integer(:account_id, null: false)
      t.timestamps(null: false)
    end
  end
end
