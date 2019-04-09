class AddInvalidLetterAddressEdipisIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index :invalid_letter_address_edipis, :edipi, algorithm: :concurrently
  end
end
