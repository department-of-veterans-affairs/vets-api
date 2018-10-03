class CreateTimeOfNeedSubmissions < ActiveRecord::Migration
  def change
    create_table :time_of_need_submissions do |t|

      t.string :burial_activity_type
      t.string :remains_type
      t.string :emblem_code
      t.string :subsequent_indicator
      t.string :liner_type
      t.string :liner_size
      t.string :cremains_type
      t.string :cemetery_type

      t.timestamps null: false
    end
  end
end
