class CreateUserActionEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :user_action_events do |t|
      # From diagram
      t.string :details

      t.timestamps null: false
    end
  end
end 