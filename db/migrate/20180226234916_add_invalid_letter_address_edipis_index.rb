class AddInvalidLetterAddressEdipisIndex < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :invalid_letter_address_edipis, :edipi, algorithm: :concurrently
  end
end
