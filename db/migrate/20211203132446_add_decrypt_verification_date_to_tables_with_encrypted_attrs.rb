class AddDecryptVerificationDateToTablesWithEncryptedAttrs < ActiveRecord::Migration[6.1]
  def change
    # appeal_submissions
    add_column :appeal_submissions, :verified_decryptable_at, :date

    # appeals_api_evidence_submissions
    add_column :appeals_api_evidence_submissions, :verified_decryptable_at, :date

    # appeals_api_higher_level_reviews
    add_column :appeals_api_higher_level_reviews, :verified_decryptable_at, :date

    # appeals_api_notice_of_disagreements
    add_column :appeals_api_notice_of_disagreements, :verified_decryptable_at, :date

    # appeals_api_supplemental_claims
    add_column :appeals_api_supplemental_claims, :verified_decryptable_at, :date

    # async_transactions
    add_column :async_transactions, :verified_decryptable_at, :date

    # claims_api_auto_established_claims
    add_column :claims_api_auto_established_claims, :verified_decryptable_at, :date

    # claims_api_power_of_attorneys
    add_column :claims_api_power_of_attorneys, :verified_decryptable_at, :date

    # claims_api_supporting_documents
    add_column :claims_api_supporting_documents, :verified_decryptable_at, :date

    # covid_vaccine_expanded_registration_submissions
    add_column :covid_vaccine_expanded_registration_submissions, :verified_decryptable_at, :date

    # covid_vaccine_registration_submissions
    add_column :covid_vaccine_registration_submissions, :verified_decryptable_at, :date

    # education_benefits_claims
    add_column :education_benefits_claims, :verified_decryptable_at, :date

    # education_stem_automated_decisions
    add_column :education_stem_automated_decisions, :verified_decryptable_at, :date

    # form526_submissions
    add_column :form526_submissions, :verified_decryptable_at, :date

    # form_attachments
    add_column :form_attachments, :verified_decryptable_at, :date

    # gibs_not_found_users
    add_column :gibs_not_found_users, :verified_decryptable_at, :date

    # health_quest_questionnaire_responses
    add_column :health_quest_questionnaire_responses, :verified_decryptable_at, :date

    # in_progress_forms
    add_column :in_progress_forms, :verified_decryptable_at, :date

    # persistent_attachments
    add_column :persistent_attachments, :verified_decryptable_at, :date

    # saved_claims
    add_column :saved_claims, :verified_decryptable_at, :date

    # veteran_representatives
    add_column :veteran_representatives, :verified_decryptable_at, :date
  end
end
