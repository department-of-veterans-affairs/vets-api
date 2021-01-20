class AddColumnsToEducationStemAutomatedDecisions < ActiveRecord::Migration[6.0]
  def change
    add_column :education_stem_automated_decisions, :poa, :boolean
    add_column :education_stem_automated_decisions, :encrypted_auth_headers_json, :string
  end
end
