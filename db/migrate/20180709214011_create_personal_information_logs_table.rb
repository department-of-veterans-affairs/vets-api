class CreatePersonalInformationLogsTable < ActiveRecord::Migration
  safety_assured

  def change
    create_table :personal_information_logs do |t|
      t.jsonb(:data, null: false)
      t.string(:error_class, null: false)
    end

    add_index(:personal_information_logs, :error_class)
  end
end
