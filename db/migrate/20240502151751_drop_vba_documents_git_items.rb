class DropVBADocumentsGitItems < ActiveRecord::Migration[7.1]
  def change
    drop_table :vba_documents_git_items, if_exists: true
  end
end
