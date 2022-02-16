class RemoveMobileVaccine < ActiveRecord::Migration[6.1]
  def change
    drop_table :mobile_vaccines
  end
end
