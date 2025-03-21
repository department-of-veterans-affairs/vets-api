class AddVesDetailsToIvcChampvaForms < ActiveRecord::Migration[7.2]
  def change
    add_column :ivc_champva_forms, :application_uuid, :uuid
    add_column :ivc_champva_forms, :ves_status, :string
    add_column :ivc_champva_forms, :ves_data, :jsonb
  end
end
