class UpdateVsscExtractDateValue < ActiveRecord::Migration[5.2]
    def up
      DrivetimeBand.update_all("vssc_extract_date='2019-10-31 00:00:00'")
    end
  
    def down
    end
end
