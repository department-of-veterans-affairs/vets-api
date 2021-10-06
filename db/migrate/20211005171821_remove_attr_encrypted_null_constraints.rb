class RemoveAttrEncryptedNullConstraints < ActiveRecord::Migration[6.1]
  def change
    change_column_null :claims_api_supporting_documents, :encrypted_file_data, true
    change_column_null :claims_api_supporting_documents, :encrypted_file_data_iv, true

    change_column_null :form526_submissions, :encrypted_auth_headers_json, null: true
    change_column_null :form526_submissions, :encrypted_auth_headers_json_iv, null: true
    change_column_null :form526_submissions, :encrypted_form_json, null: true
    change_column_null :form526_submissions, :encrypted_form_json_iv, null: true



    change_column_null :form_attachments, :encrypted_file_data, null: true
    change_column_null :form_attachments, :encrypted_file_data_iv, null: true


    change_column_null :gibs_not_found_users, :encrypted_ssn, null: true
    change_column_null :gibs_not_found_users, :encrypted_ssn_iv, null: true


    change_column_null :health_quest_questionnaire_responses, :encrypted_questionnaire_response_data, null: true
    change_column_null :health_quest_questionnaire_responses, :encrypted_questionnaire_response_data_iv, null: true
    change_column_null :health_quest_questionnaire_responses, :encrypted_user_demographics_data, null: true
    change_column_null :health_quest_questionnaire_responses, :encrypted_user_demographics_data_iv, null: true


    change_column_null :in_progress_forms, :encrypted_form_data, null: true
    change_column_null :in_progress_forms, :encrypted_form_data_iv, null: true


    change_column_null :persistent_attachments, :encrypted_file_data, null: true
    change_column_null :persistent_attachments, :encrypted_file_data_iv, null: true

    change_column_null :saved_claims, :encrypted_form, null: true
    change_column_null :saved_claims, :encrypted_form_iv, null: true
  end
end
