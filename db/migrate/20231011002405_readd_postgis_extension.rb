class ReaddPostgisExtension < ActiveRecord::Migration[6.1]
  def up
    connection.execute('CREATE EXTENSION "postgis"')
  end
end
