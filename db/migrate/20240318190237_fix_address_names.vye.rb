# This migration comes from vye (originally 20240318162206)
class FixAddressNames < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_columns(
        :vye_address_changes,
        :address_line5_ciphertext,
        :address_line6_ciphertext
      )
    end

    add_column :vye_address_changes, :address5_ciphertext, :text
  end
end
