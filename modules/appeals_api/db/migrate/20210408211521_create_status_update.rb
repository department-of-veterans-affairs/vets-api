class CreateStatusUpdate < ActiveRecord::Migration[6.0]
  def change
    create_table :status_updates do |t|
      t.string :from
      t.string :to
      t.references :appeal, polymorphic: true, type: :string, index: { name: 'status_update_id_type_index' }
      t.datetime :status_update_time

      t.timestamps
    end
  end
end
