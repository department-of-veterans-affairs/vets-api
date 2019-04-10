class AddDisabilityContentionsMedicalIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!
  safety_assured

  def up
    execute <<-SQL
      CREATE INDEX CONCURRENTLY index_disability_contentions_on_medical_term ON disability_contentions USING gin(medical_term gin_trgm_ops);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX index_disability_contentions_on_medical_term;
    SQL
  end
end
