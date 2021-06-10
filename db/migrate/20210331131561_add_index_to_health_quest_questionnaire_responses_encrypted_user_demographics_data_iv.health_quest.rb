class AddIndexToHealthQuestQuestionnaireResponsesEncryptedUserDemographicsDataIv < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :health_quest_questionnaire_responses, :encrypted_user_demographics_data_iv, unique: true, algorithm: :concurrently, name: 'user_demographics_key'
  end
end
