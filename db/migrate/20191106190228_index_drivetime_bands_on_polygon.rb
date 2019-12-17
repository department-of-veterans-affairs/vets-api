class IndexDrivetimeBandsOnPolygon < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :drivetime_bands, :polygon, using: 'gist', algorithm: :concurrently
  end
end
