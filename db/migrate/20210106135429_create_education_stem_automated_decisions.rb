class CreateEducationStemAutomatedDecisions < ActiveRecord::Migration[6.0]
  def change
    create_table :education_stem_automated_decisions do |t|
      t.bigint "education_benefits_claim_id"
      t.string "automated_decision_state", default: 'init'
      t.string "user_uuid", null: false
      t.timestamps(null: false)
      t.index "user_uuid"
      t.index "education_benefits_claim_id", name: "index_education_stem_automated_decisions_on_claim_id"
    end
  end
end
