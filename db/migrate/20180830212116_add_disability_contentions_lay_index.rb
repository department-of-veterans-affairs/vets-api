class AddDisabilityContentionsLayIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!
  safety_assured

  def up
    execute <<-SQL
      CREATE INDEX CONCURRENTLY index_disability_contentions_on_lay_term ON disability_contentions USING gin(lay_term gin_trgm_ops);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX index_disability_contentions_on_lay_term;
    SQL
  end
end
