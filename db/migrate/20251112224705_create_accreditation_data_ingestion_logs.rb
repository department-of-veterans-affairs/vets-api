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

    # Index for finding most recent successful ingestion (any dataset)
    # Supports: WHERE status = X ORDER BY finished_at DESC
    add_index :accreditation_data_ingestion_logs,
              %i[status finished_at],
              name: 'index_accr_data_ing_logs_on_status_and_finished_at'

    # Index for finding most recent successful ingestion for a specific dataset
    # Supports: WHERE dataset = X AND status = X ORDER BY finished_at DESC
    add_index :accreditation_data_ingestion_logs,
              %i[dataset status finished_at],
              name: 'index_accr_data_ing_logs_on_dataset_status_finished_at'

    # Index for finding most recently started ingestion for a specific dataset
    # Supports: WHERE dataset = X ORDER BY started_at DESC
    add_index :accreditation_data_ingestion_logs,
              %i[dataset started_at],
              name: 'index_accr_data_ing_logs_on_dataset_started_at'
  end
end
