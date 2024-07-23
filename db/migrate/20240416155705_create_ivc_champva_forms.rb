class CreateIvcChampvaForms < ActiveRecord::Migration[7.1]
  def change
    create_table :ivc_champva_forms do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :form_number
      t.string :file_name
      t.uuid   :form_uuid
      t.string :s3_status
      t.string :pega_status

      t.timestamps
    end

    add_index :ivc_champva_forms, :email, unique: true
  end
end