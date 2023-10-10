class DropPostgisExtension < ActiveRecord::Migration[6.1]
  def up
    connection.execute('drop extension "postgis"')
  end
end
