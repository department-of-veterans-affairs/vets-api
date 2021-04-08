# frozen_string_literal: true
# This migration comes from health_quest (originally 20210330134533)

class CreateQuestionnaireResponses < ActiveRecord::Migration[6.0]
  def change
    create_table :health_quest_questionnaire_responses do |t|
      t.string :user_uuid, :appointment_id, :questionnaire_response_id
      t.string :encrypted_questionnaire_response_data
      t.string :encrypted_questionnaire_response_data_iv
      t.string :encrypted_user_demographics_data
      t.string :encrypted_user_demographics_data_iv
      t.timestamps
    end
  end
end
