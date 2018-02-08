class AddVICSubmissionsTable < ActiveRecord::Migration
  def change
    create_table "vic_submissions" do |t|
      t.timestamps(null: false)
      t.string(:state, null: false, default: 'pending')
      t.uuid(:guid, null: false)
      t.json(:response)
    end
  end
end
