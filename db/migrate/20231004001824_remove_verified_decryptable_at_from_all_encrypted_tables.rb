class RemoveVerifiedDecryptableAtFromAllEncryptedTables < ActiveRecord::Migration[6.1]
  def change
    # appeal_submissions
    safety_assured { remove_column :appeal_submissions, :verified_decryptable_at, :datetime }

    # appeals_api_evidence_submissions
    safety_assured { remove_column :appeals_api_evidence_submissions, :verified_decryptable_at, :datetime }

    # appeals_api_higher_level_reviews
    safety_assured { remove_column :appeals_api_higher_level_reviews, :verified_decryptable_at, :datetime }

    # appeals_api_notice_of_disagreements
    safety_assured { remove_column :appeals_api_notice_of_disagreements, :verified_decryptable_at, :datetime }

    # appeals_api_supplemental_claims
    safety_assured { remove_column :appeals_api_supplemental_claims, :verified_decryptable_at, :datetime }

    # async_transactions
    safety_assured { remove_column :async_transactions, :verified_decryptable_at, :datetime }

    # claims_api_auto_established_claims
    safety_assured { remove_column :claims_api_auto_established_claims, :verified_decryptable_at, :datetime }

    # claims_api_power_of_attorneys
    safety_assured { remove_column :claims_api_power_of_attorneys, :verified_decryptable_at, :datetime }

    # claims_api_supporting_documents
    safety_assured { remove_column :claims_api_supporting_documents, :verified_decryptable_at, :datetime }

    # covid_vaccine_expanded_registration_submissions
    safety_assured { remove_column :covid_vaccine_expanded_registration_submissions, :verified_decryptable_at, :datetime }

    # covid_vaccine_registration_submissions
    safety_assured { remove_column :covid_vaccine_registration_submissions, :verified_decryptable_at, :datetime }

    # education_benefits_claims
    safety_assured { remove_column :education_benefits_claims, :verified_decryptable_at, :datetime }

    # education_stem_automated_decisions
    safety_assured { remove_column :education_stem_automated_decisions, :verified_decryptable_at, :datetime }

    # form526_submissions
    safety_assured { remove_column :form526_submissions, :verified_decryptable_at, :datetime }

    # form_attachments
    safety_assured { remove_column :form_attachments, :verified_decryptable_at, :datetime }

    # gibs_not_found_users
    safety_assured { remove_column :gibs_not_found_users, :verified_decryptable_at, :datetime }

    # health_quest_questionnaire_responses
    safety_assured { remove_column :health_quest_questionnaire_responses, :verified_decryptable_at, :datetime }

    # in_progress_forms
    safety_assured { remove_column :in_progress_forms, :verified_decryptable_at, :datetime }

    # persistent_attachments
    safety_assured { remove_column :persistent_attachments, :verified_decryptable_at, :datetime }

    # saved_claims
    safety_assured { remove_column :saved_claims, :verified_decryptable_at, :datetime }

    # veteran_representatives
    safety_assured { remove_column :veteran_representatives, :verified_decryptable_at, :datetime }
  end
end
