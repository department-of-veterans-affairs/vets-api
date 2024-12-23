class AddPathToBanners < ActiveRecord::Migration[7.2]
  def change
    add_column :banners, :path, :string
  end
end
