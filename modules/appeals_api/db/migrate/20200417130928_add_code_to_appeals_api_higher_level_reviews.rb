# frozen_string_literal: true

class AddCodeToAppealsApiHigherLevelReviews < ActiveRecord::Migration[5.2]
  def change
    add_column :appeals_api_higher_level_reviews, :code, :string
    add_column :appeals_api_higher_level_reviews, :detail, :string
  end
end
