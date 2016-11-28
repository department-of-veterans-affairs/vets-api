class TransformEvssData < ActiveRecord::Migration
  def up
    DisabilityClaim.all.each do |claim|
      claim.data.deep_transform_keys!(&:underscore)
      claim.list_data.deep_transform_keys!(&:underscore)
      claim.save
    end
  end

  def down
    DisabilityClaim.all.each do |claim|
      claim.data.deep_transform_keys!(&:camelcase)
      claim.list_data.deep_transform_keys!(&:camelcase)
      claim.save
    end
  end
end
