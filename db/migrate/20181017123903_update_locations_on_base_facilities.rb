class UpdateLocationsOnBaseFacilities < ActiveRecord::Migration
  def up
    execute "UPDATE base_facilities SET location=ST_GeogFromText('SRID=4326;POINT(' || long || ' ' || lat ||')')"
  end

  def down; end
end
