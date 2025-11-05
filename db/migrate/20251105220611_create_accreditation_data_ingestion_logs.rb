class CreateAccreditationDataIngestionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :accreditation_data_ingestion_logs do |t|
      t.integer :dataset, null: false
      t.integer :status, null: false, default: 0
      t.integer :agents_status, null: false, default: 0
      t.integer :attorneys_status, null: false, default: 0
      t.integer :representatives_status, null: false, default: 0
      t.integer :veteran_service_organizations_status, null: false, default: 0
      t.datetime :started_at, default: -> { 'CURRENT_TIMESTAMP' }, null: false
      t.datetime :finished_at
      t.jsonb :metrics, default: {}, null: false
      t.timestamps
    end
  end
end
