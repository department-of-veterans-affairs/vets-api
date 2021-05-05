class AddIndexToHealthQuestQuestionnaireResponsesEncryptedQuestionnaireResponseDataIv < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :health_quest_questionnaire_responses, :encrypted_questionnaire_response_data_iv, unique: true, algorithm: :concurrently, name: 'qr_key'
  end
end
