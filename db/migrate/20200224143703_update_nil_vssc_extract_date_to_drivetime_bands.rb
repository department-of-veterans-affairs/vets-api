class UpdateNilVsscExtractDateToDrivetimeBands < ActiveRecord::Migration[5.2]
  def change
    DrivetimeBand.where(vssc_extract_date: nil).update_all(vssc_extract_date: '2001-01-01 00:00:00')
  end
end
