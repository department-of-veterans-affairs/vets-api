class AddKmsEncryptionFields < ActiveRecord::Migration[6.1]
  def change
    # appeal_submissions
    add_column :appeal_submissions, :encrypted_kms_key, :text

    # appeals_api_evidence_submissions
    add_column :appeals_api_evidence_submissions, :encrypted_kms_key, :text

    # appeals_api_higher_level_reviews
    add_column :appeals_api_higher_level_reviews, :encrypted_kms_key, :text

    # appeals_api_notice_of_disagreements
    add_column :appeals_api_notice_of_disagreements, :encrypted_kms_key, :text

    # appeals_api_supplemental_claims
    add_column :appeals_api_supplemental_claims, :encrypted_kms_key, :text

    # async_transactions
    add_column :async_transactions, :encrypted_kms_key, :text

    # claims_api_auto_established_claims
    add_column :claims_api_auto_established_claims, :encrypted_kms_key, :text

    # claims_api_power_of_attorneys
    add_column :claims_api_power_of_attorneys, :encrypted_kms_key, :text

    # claims_api_supporting_documents
    add_column :claims_api_supporting_documents, :encrypted_kms_key, :text

    # covid_vaccine_expanded_registration_submissions
    add_column :covid_vaccine_expanded_registration_submissions, :encrypted_kms_key, :text

    # covid_vaccine_registration_submissions
    add_column :covid_vaccine_registration_submissions, :encrypted_kms_key, :text

    # education_benefits_claims
    add_column :education_benefits_claims, :encrypted_kms_key, :text

    # education_stem_automated_decisions
    add_column :education_stem_automated_decisions, :encrypted_kms_key, :text

    # form526_submissions
    add_column :form526_submissions, :encrypted_kms_key, :text

    # form_attachments
    add_column :form_attachments, :encrypted_kms_key, :text

    # gibs_not_found_users
    add_column :gibs_not_found_users, :encrypted_kms_key, :text

    # health_quest_questionnaire_responses
    add_column :health_quest_questionnaire_responses, :encrypted_kms_key, :text

    # in_progress_forms
    add_column :in_progress_forms, :encrypted_kms_key, :text

    # persistent_attachments
    add_column :persistent_attachments, :encrypted_kms_key, :text

    # saved_claims
    add_column :saved_claims, :encrypted_kms_key, :text

    # veteran_representatives
    add_column :veteran_representatives, :encrypted_kms_key, :text
  end
end
