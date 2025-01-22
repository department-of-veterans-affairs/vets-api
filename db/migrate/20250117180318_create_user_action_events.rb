# frozen_string_literal: true

class CreateUserActionEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :user_action_events do |t|
      t.string :details, null: false
      t.timestamps null: false
    end
  end
end
