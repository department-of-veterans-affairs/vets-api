class AddVsscExtractDateDrivetimeBandsDefault < ActiveRecord::Migration[5.2]
  def change
      change_column_default :drivetime_bands, :vssc_extract_date, "2001-01-01 00:00:00"
  end
end
