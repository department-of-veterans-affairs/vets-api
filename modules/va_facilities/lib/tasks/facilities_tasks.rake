# frozen_string_literal: true

# desc "Explaining what the task does"
task :migrate_points_for_facilities do
  sql = <<-SQL
    UPDATE base_facilities
    SET location=ST_GeogFromText('SRID=4326;POINT(' || long || ' ' || lat ||')')
  SQL
  ActiveRecord::Base.conection.execute sql
end
