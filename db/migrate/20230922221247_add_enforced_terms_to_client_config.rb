class AddEnforcedTermsToClientConfig < ActiveRecord::Migration[6.1]
  def change
    add_column :client_configs, :terms_of_use_url, :text
    add_column :client_configs, :enforced_terms, :text
  end
end
