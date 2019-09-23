class AddMobileFlagToBaseFacilities < ActiveRecord::Migration[5.2]
  def change
    add_column :base_facilities, :mobile, :boolean
  end
end
