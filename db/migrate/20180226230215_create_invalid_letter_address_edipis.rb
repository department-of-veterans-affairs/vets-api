class CreateInvalidLetterAddressEdipis < ActiveRecord::Migration[4.2]
  def change
    create_table :invalid_letter_address_edipis do |t|
      t.string :edipi, null: false, unique: true
      t.timestamps null: false
    end
  end
end
