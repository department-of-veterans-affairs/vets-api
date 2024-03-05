# frozen_string_literal: true

class CreateVyeAwards < ActiveRecord::Migration[6.1]
  def change
    create_table :vye_awards do |t|
      t.integer :user_info_id
      t.string :cur_award_ind
      t.datetime :award_begin_date
      t.datetime :award_end_date
      t.integer :training_time
      t.datetime :payment_date
      t.decimal :monthly_rate
      t.string :begin_rsn
      t.string :end_rsn
      t.string :type_training
      t.integer :number_hours
      t.string :type_hours

      t.timestamps

      t.index :user_info_id
    end
  end
end
