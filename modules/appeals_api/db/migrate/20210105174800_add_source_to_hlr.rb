class AddSourceToHlr < ActiveRecord::Migration[6.0]
  def change
    add_column :appeals_api_higher_level_reviews, :source, :string
  end
end
