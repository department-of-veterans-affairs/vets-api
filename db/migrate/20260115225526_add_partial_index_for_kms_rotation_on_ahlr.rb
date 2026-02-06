class AddPartialIndexForKmsRotationOnAhlr < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute <<~SQL
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ahlr_kms_rotation_true_id
        ON appeals_api_higher_level_reviews (id)
        WHERE needs_kms_rotation = true;
      SQL
    end
  end

  def down
    safety_assured do
        execute <<~SQL
          DROP INDEX CONCURRENTLY IF EXISTS idx_ahlr_kms_rotation_true_id;
        SQL
      end
    end
end
