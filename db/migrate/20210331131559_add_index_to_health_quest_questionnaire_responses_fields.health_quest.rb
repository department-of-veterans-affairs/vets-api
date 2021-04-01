# frozen_string_literal: true

class AddIndexToHealthQuestQuestionnaireResponsesFields < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :health_quest_questionnaire_responses, [:user_uuid, :questionnaire_response_id], unique: true, algorithm: :concurrently, name: 'find_by_user_qr'
  end
end
