class AddVsscExtractDateToDrivetimeBands < ActiveRecord::Migration[5.2]
  def change
    add_column :drivetime_bands, :vssc_extract_date, :datetime
  end
end
