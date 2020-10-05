class FixDirectoryApplicationServiceCategoriesColumnName < ActiveRecord::Migration[6.0]
  def change
    rename_column :directory_applications, :service_cattegories, :service_categories
  end
end
