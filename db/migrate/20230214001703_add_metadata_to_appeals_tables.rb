class AddMetadataToAppealsTables < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :appeals_api_higher_level_reviews, :metadata, :jsonb, default: {}
      add_column :appeals_api_notice_of_disagreements, :metadata, :jsonb, default: {}
      add_column :appeals_api_supplemental_claims, :metadata, :jsonb, default: {}
    end
  end
end
