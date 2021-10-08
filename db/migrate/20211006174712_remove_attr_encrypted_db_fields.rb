class RemoveAttrEncryptedDbFields < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      # appeal_submissions
      remove_column :appeal_submissions, :encrypted_upload_metadata, :string
      remove_column :appeal_submissions, :encrypted_upload_metadata_iv, :string

      # appeals_api_evidence_submissions
      remove_column :appeals_api_evidence_submissions, :encrypted_file_data, :string
      remove_column :appeals_api_evidence_submissions, :encrypted_file_data_iv, :string

      # appeals_api_higher_level_reviews
      remove_column :appeals_api_higher_level_reviews, :encrypted_form_data, :string
      remove_column :appeals_api_higher_level_reviews, :encrypted_auth_headers, :string
      remove_column :appeals_api_higher_level_reviews, :encrypted_form_data_iv, :string
      remove_column :appeals_api_higher_level_reviews, :encrypted_auth_headers_iv, :string

      # appeals_api_notice_of_disagreements
      remove_column :appeals_api_notice_of_disagreements, :encrypted_form_data, :string
      remove_column :appeals_api_notice_of_disagreements, :encrypted_auth_headers, :string
      remove_column :appeals_api_notice_of_disagreements, :encrypted_form_data_iv, :string
      remove_column :appeals_api_notice_of_disagreements, :encrypted_auth_headers_iv, :string

      # appeals_api_supplemental_claims
      remove_column :appeals_api_supplemental_claims, :encrypted_form_data, :string
      remove_column :appeals_api_supplemental_claims, :encrypted_auth_headers, :string
      remove_column :appeals_api_supplemental_claims, :encrypted_form_data_iv, :string
      remove_column :appeals_api_supplemental_claims, :encrypted_auth_headers_iv, :string

      # async_transactions
      remove_column :async_transactions, :encrypted_metadata, :string
      remove_column :async_transactions, :encrypted_metadata_iv, :string

      # claims_api_auto_established_claims
      remove_column :claims_api_auto_established_claims, :encrypted_form_data, :string
      remove_column :claims_api_auto_established_claims, :encrypted_auth_headers, :string
      remove_column :claims_api_auto_established_claims, :encrypted_file_data, :string
      remove_column :claims_api_auto_established_claims, :encrypted_evss_response, :string
      remove_column :claims_api_auto_established_claims, :encrypted_bgs_flash_responses, :string
      remove_column :claims_api_auto_established_claims, :encrypted_bgs_special_issue_responses, :string
      remove_column :claims_api_auto_established_claims, :encrypted_form_data_iv, :string
      remove_column :claims_api_auto_established_claims, :encrypted_auth_headers_iv, :string
      remove_column :claims_api_auto_established_claims, :encrypted_file_data_iv, :string
      remove_column :claims_api_auto_established_claims, :encrypted_evss_response_iv, :string
      remove_column :claims_api_auto_established_claims, :encrypted_bgs_flash_responses_iv, :string
      remove_column :claims_api_auto_established_claims, :encrypted_bgs_special_issue_responses_iv, :string

      # claims_api_power_of_attorneys
      remove_column :claims_api_power_of_attorneys, :encrypted_form_data, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_auth_headers, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_file_data, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_source_data, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_form_data_iv, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_auth_headers_iv, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_file_data_iv, :string
      remove_column :claims_api_power_of_attorneys, :encrypted_source_data_iv, :string

      # claims_api_supporting_documents
      remove_column :claims_api_supporting_documents, :encrypted_file_data, :string
      remove_column :claims_api_supporting_documents, :encrypted_file_data_iv, :string

      # covid_vaccine_expanded_registration_submissions
      remove_column :covid_vaccine_expanded_registration_submissions, :encrypted_raw_form_data, :string
      remove_column :covid_vaccine_expanded_registration_submissions, :encrypted_eligibility_info, :string
      remove_column :covid_vaccine_expanded_registration_submissions, :encrypted_form_data, :string
      remove_column :covid_vaccine_expanded_registration_submissions, :encrypted_raw_form_data_iv, :string
      remove_column :covid_vaccine_expanded_registration_submissions, :encrypted_eligibility_info_iv, :string
      remove_column :covid_vaccine_expanded_registration_submissions, :encrypted_form_data_iv, :string

      # covid_vaccine_registration_submissions
      remove_column :covid_vaccine_registration_submissions, :encrypted_form_data, :string
      remove_column :covid_vaccine_registration_submissions, :encrypted_raw_form_data, :string
      remove_column :covid_vaccine_registration_submissions, :encrypted_form_data_iv, :string
      remove_column :covid_vaccine_registration_submissions, :encrypted_raw_form_data_iv, :string

      # education_benefits_claims
      remove_column :education_benefits_claims, :encrypted_form, :string
      remove_column :education_benefits_claims, :encrypted_form_iv, :string

      # education_stem_automated_decisions
      remove_column :education_stem_automated_decisions, :encrypted_auth_headers_json, :string
      remove_column :education_stem_automated_decisions, :encrypted_auth_headers_json_iv, :string

      # form526_submissions
      remove_column :form526_submissions, :encrypted_auth_headers_json, :string
      remove_column :form526_submissions, :encrypted_form_json, :string
      remove_column :form526_submissions, :encrypted_birls_ids_tried, :string
      remove_column :form526_submissions, :encrypted_auth_headers_json_iv, :string
      remove_column :form526_submissions, :encrypted_form_json_iv, :string
      remove_column :form526_submissions, :encrypted_birls_ids_tried_iv, :string

      # form_attachments
      remove_column :form_attachments, :encrypted_file_data, :string
      remove_column :form_attachments, :encrypted_file_data_iv, :string

      # gibs_not_found_users
      remove_column :gibs_not_found_users, :encrypted_ssn, :string
      remove_column :gibs_not_found_users, :encrypted_ssn_iv, :string

      # health_quest_questionnaire_responses
      remove_column :health_quest_questionnaire_responses, :encrypted_questionnaire_response_data, :string
      remove_column :health_quest_questionnaire_responses, :encrypted_user_demographics_data, :string
      remove_column :health_quest_questionnaire_responses, :encrypted_questionnaire_response_data_iv, :string
      remove_column :health_quest_questionnaire_responses, :encrypted_user_demographics_data_iv, :string

      # in_progress_forms
      remove_column :in_progress_forms, :encrypted_form_data, :string
      remove_column :in_progress_forms, :encrypted_form_data_iv, :string

      # persistent_attachments
      remove_column :persistent_attachments, :encrypted_file_data, :string
      remove_column :persistent_attachments, :encrypted_file_data_iv, :string

      # saved_claims
      remove_column :saved_claims, :encrypted_form, :string
      remove_column :saved_claims, :encrypted_form_iv, :string

      # veteran_representatives
      remove_column :veteran_representatives, :encrypted_ssn, :string
      remove_column :veteran_representatives, :encrypted_dob, :string
      remove_column :veteran_representatives, :encrypted_ssn_iv, :string
      remove_column :veteran_representatives, :encrypted_dob_iv, :string
    end
  end
end
