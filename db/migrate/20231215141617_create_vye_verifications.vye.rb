# frozen_string_literal: true
# This migration comes from vye (originally 20231120040026)

class CreateVyeVerifications < ActiveRecord::Migration[6.1]
  def change
    create_table :vye_verifications do |t|
      t.integer :user_info_id
      t.integer :award_id
      t.string :change_flag
      t.integer :rpo_code
      t.boolean :rpo_flag
      t.datetime :act_begin
      t.datetime :act_end
      t.string :source_ind

      t.timestamps

      t.index :user_info_id
    end
  end
end
