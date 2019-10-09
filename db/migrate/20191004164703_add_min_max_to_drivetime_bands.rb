class AddMinMaxToDrivetimeBands < ActiveRecord::Migration[5.2]
  def change
    add_column :drivetime_bands, :min, :integer
    add_column :drivetime_bands, :max, :integer
    remove_column :drivetime_bands, :value, :integer
  end
end
