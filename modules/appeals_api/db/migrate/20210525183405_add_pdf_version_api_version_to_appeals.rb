class AddPdfVersionApiVersionToAppeals < ActiveRecord::Migration[6.0]
  def change
    add_column :appeals_api_higher_level_reviews, :pdf_version, :string
    add_column :appeals_api_higher_level_reviews, :api_version, :string
    add_column :appeals_api_notice_of_disagreements, :pdf_version, :string
    add_column :appeals_api_notice_of_disagreements, :api_version, :string
 end
end
