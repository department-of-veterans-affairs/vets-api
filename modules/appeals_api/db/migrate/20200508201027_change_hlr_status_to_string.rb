# frozen_string_literal: true

class ChangeHlrStatusToString < ActiveRecord::Migration[6.0]
  def change
    change_column :appeals_api_higher_level_reviews, :status, :string, default: 'pending', null: false
  end
end
