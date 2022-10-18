class AddCodeDetailToAppealsApiStatusUpdates < ActiveRecord::Migration[6.1]
  def change
    add_column :appeals_api_status_updates, :code, :string
    add_column :appeals_api_status_updates, :detail, :string
  end
end
