class AddColumnToEducationStemAutomatedDecisions < ActiveRecord::Migration[6.0]
  def change
    add_column :education_stem_automated_decisions, :encrypted_auth_headers_json_iv, :string
  end
end
