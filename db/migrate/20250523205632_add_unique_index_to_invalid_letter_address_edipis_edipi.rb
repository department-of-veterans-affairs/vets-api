class AddUniqueIndexToInvalidLetterAddressEdipisEdipi < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :invalid_letter_address_edipis, column: :edipi, algorithm: :concurrently
    add_index :invalid_letter_address_edipis, :edipi, unique: true, name: "index_invalid_letter_address_edipis_on_edipi", algorithm: :concurrently
  end
end
