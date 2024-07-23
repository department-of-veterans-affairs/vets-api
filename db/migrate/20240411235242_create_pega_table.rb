class CreatePegaTable < ActiveRecord::Migration[7.1]
  def change
    create_table :pega_tables do |t|
      t.uuid :uuid
      t.string :veteranfirstname
      t.string :veteranmiddlename
      t.string :veteranlastname
      t.string :applicantfirstname
      t.string :applicantmiddlename
      t.string :applicantlastname
      t.jsonb :response
      t.string :filenumber
      t.string :doctype
      t.datetime :date_created
      t.datetime :date_completed

      t.timestamps
    end
  end
end
