class AddPoaToEducationStemAutomatedDecisions < ActiveRecord::Migration[6.0]
  def change
    add_column :education_stem_automated_decisions, :poa, :boolean
  end
end
