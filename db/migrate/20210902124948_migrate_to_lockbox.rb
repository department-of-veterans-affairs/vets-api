
class MigrateToLockbox < ActiveRecord::Migration[6.1]
  def change
    # appeal_submissions
    add_column :appeal_submissions, :upload_metadata_ciphertext, :text

    # appeals_api_evidence_submissions
    add_column :appeals_api_evidence_submissions, :file_data_ciphertext, :text

    # appeals_api_higher_level_reviews
    add_column :appeals_api_higher_level_reviews, :form_data_ciphertext, :text
    add_column :appeals_api_higher_level_reviews, :auth_headers_ciphertext, :text

    # appeals_api_notice_of_disagreements
    add_column :appeals_api_notice_of_disagreements, :form_data_ciphertext, :text
    add_column :appeals_api_notice_of_disagreements, :auth_headers_ciphertext, :text

    # appeals_api_supplemental_claims
    add_column :appeals_api_supplemental_claims, :form_data_ciphertext, :text
    add_column :appeals_api_supplemental_claims, :auth_headers_ciphertext, :text

    # async_transactions
    add_column :async_transactions, :metadata_ciphertext, :text

    # claims_api_auto_established_claims
    add_column :claims_api_auto_established_claims, :form_data_ciphertext, :text
    add_column :claims_api_auto_established_claims, :auth_headers_ciphertext, :text
    add_column :claims_api_auto_established_claims, :file_data_ciphertext, :text
    add_column :claims_api_auto_established_claims, :evss_response_ciphertext, :text
    add_column :claims_api_auto_established_claims, :bgs_flash_responses_ciphertext, :text
    add_column :claims_api_auto_established_claims, :bgs_special_issue_responses_ciphertext, :text

    # claims_api_power_of_attorneys
    add_column :claims_api_power_of_attorneys, :form_data_ciphertext, :text
    add_column :claims_api_power_of_attorneys, :auth_headers_ciphertext, :text
    add_column :claims_api_power_of_attorneys, :file_data_ciphertext, :text
    add_column :claims_api_power_of_attorneys, :source_data_ciphertext, :text

    # claims_api_supporting_documents
    add_column :claims_api_supporting_documents, :file_data_ciphertext, :text

    # covid_vaccine_expanded_registration_submissions
    add_column :covid_vaccine_expanded_registration_submissions, :raw_form_data_ciphertext, :text
    add_column :covid_vaccine_expanded_registration_submissions, :eligibility_info_ciphertext, :text
    add_column :covid_vaccine_expanded_registration_submissions, :form_data_ciphertext, :text

    # covid_vaccine_registration_submissions
    add_column :covid_vaccine_registration_submissions, :form_data_ciphertext, :text
    add_column :covid_vaccine_registration_submissions, :raw_form_data_ciphertext, :text

    # education_benefits_claims
    add_column :education_benefits_claims, :form_ciphertext, :text

    # education_stem_automated_decisions
    add_column :education_stem_automated_decisions, :auth_headers_json_ciphertext, :text

    # form526_submissions
    add_column :form526_submissions, :auth_headers_json_ciphertext, :text
    add_column :form526_submissions, :form_json_ciphertext, :text
    add_column :form526_submissions, :birls_ids_tried_ciphertext, :text

    # form_attachments
    add_column :form_attachments, :file_data_ciphertext, :text

    # gibs_not_found_users
    add_column :gibs_not_found_users, :ssn_ciphertext, :text

    # health_quest_questionnaire_responses
    add_column :health_quest_questionnaire_responses, :questionnaire_response_data_ciphertext, :text
    add_column :health_quest_questionnaire_responses, :user_demographics_data_ciphertext, :text

    # in_progress_forms
    add_column :in_progress_forms, :form_data_ciphertext, :text

    # persistent_attachments
    add_column :persistent_attachments, :file_data_ciphertext, :text

    # saved_claims
    add_column :saved_claims, :form_ciphertext, :text

    # veteran_representatives
    add_column :veteran_representatives, :ssn_ciphertext, :text
    add_column :veteran_representatives, :dob_ciphertext, :text
  end
end
