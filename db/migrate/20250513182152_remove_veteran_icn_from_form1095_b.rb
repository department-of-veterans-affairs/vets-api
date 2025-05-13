class RemoveVeteranIcnFromForm1095B < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :form1095_bs, :veteran_icn }
  end
end
