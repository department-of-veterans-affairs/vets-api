class CreateArIcnTemporaryIdentifiers < ActiveRecord::Migration[7.2]
  def change
    create_table :ar_icn_temporary_identifiers, id: :uuid do |t|
      t.string :icn, null: false
      t.datetime :created_at
      t.index [:icn]
      t.index [:created_at]
    end
  end
end
