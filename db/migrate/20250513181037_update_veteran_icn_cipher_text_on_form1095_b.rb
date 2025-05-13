class UpdateVeteranIcnCipherTextOnForm1095B < ActiveRecord::Migration[7.2]
  def change
    Form1095B.find_each do |form|
      form.update_attribute(:veteran_icn_ciphertext, form.veteran_icn)
    end
  end
end
