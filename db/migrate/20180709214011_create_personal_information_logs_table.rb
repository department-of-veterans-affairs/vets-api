class CreatePersonalInformationLogsTable < ActiveRecord::Migration[4.2]
  safety_assured

  def change
    create_table :personal_information_logs do |t|
      t.jsonb(:data, null: false)
      t.string(:error_class, null: false)
      t.timestamps(null: false)
    end

    add_index(:personal_information_logs, :error_class)
    add_index(:personal_information_logs, :created_at)
  end
end
