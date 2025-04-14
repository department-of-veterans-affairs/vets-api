# frozen_string_literal: true

FactoryBot.define do
  factory :form526_submission do
    transient do
      user { create(:disabilities_compensation_user) }
      submissions_path { Rails.root.join(*'/spec/support/disability_compensation_form/submissions'.split('/')).to_s }
    end
    user_uuid { user.uuid }
    saved_claim { create(:va526ez) }
    submitted_claim_id { nil }
    auth_headers_json do
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h).to_json
    end
    form_json do
      File.read("#{submissions_path}/only_526.json")
    end
    backup_submitted_claim_status { nil }
  end

  trait :backup_path do
    backup_submitted_claim_id {
      "#{SecureRandom.hex(8)}-#{SecureRandom.hex(4)}-" \
        "#{SecureRandom.hex(4)}-#{SecureRandom.hex(4)}-" \
        "#{SecureRandom.hex(12)}"
    }
  end

  trait :backup_accepted do
    backup_submitted_claim_status { 'accepted' }
  end

  trait :backup_rejected do
    backup_submitted_claim_status { 'rejected' }
  end

  trait :paranoid_success do
    backup_submitted_claim_status { 'paranoid_success' }
  end

  trait :with_everything do
    form_json do
      File.read("#{submissions_path}/with_everything.json")
    end
  end

  trait :with_0781 do # rubocop:disable Naming/VariableNumber
    form_json do
      File.read("#{submissions_path}/with_0781.json")
    end
  end

  trait :with_0781v2 do
    form_json do
      File.read("#{submissions_path}/with_0781v2.json")
    end
  end

  trait :with_everything_toxic_exposure do
    form_json do
      File.read("#{submissions_path}/with_everything_toxic_exposure.json")
    end
  end

  trait :only_526_required do
    form_json do
      File.read("#{submissions_path}/only_526_required.json")
    end
  end

  trait :with_uploads do
    form_json do
      File.read("#{submissions_path}/with_uploads.json")
    end
  end

  trait :with_non_pdf_uploads do
    form_json do
      File.read("#{submissions_path}/with_non_pdf_uploads.json")
    end
  end

  trait :with_non_us_address do
    form_json do
      File.read("#{submissions_path}/with_non_us_address.json")
    end
  end

  trait :hypertension_claim_for_increase do
    user { create(:disabilities_compensation_user, icn: '2000163') }
    form_json do
      File.read("#{submissions_path}/only_526_hypertension.json")
    end
  end

  trait :als_claim_for_increase do
    user { create(:disabilities_compensation_user, icn: '2000163') }
    form_json do
      File.read("#{submissions_path}/only_526_als.json")
    end
  end

  trait :als_claim_for_increase_terminally_ill do
    user { create(:disabilities_compensation_user, icn: '2000163') }
    form_json do
      File.read("#{submissions_path}/only_526_als_terminally_ill.json")
    end
  end

  trait :asthma_claim_for_increase do
    user { create(:disabilities_compensation_user, icn: '2000163') }
    form_json do
      File.read("#{submissions_path}/only_526_asthma.json")
    end
  end

  trait :hypertension_claim_for_increase_with_uploads do
    user { create(:disabilities_compensation_user, icn: '2000163') }
    form_json do
      json = JSON.parse(File.read("#{submissions_path}/only_526_hypertension.json"))
      uploads = JSON.parse(File.read("#{submissions_path}/with_uploads.json"))
      json['form526_uploads'] = uploads['form526_uploads']
      json.to_json
    end
  end

  trait :asthma_claim_for_increase_with_uploads do
    user { create(:disabilities_compensation_user, icn: '2000163') }
    form_json do
      json = JSON.parse(File.read("#{submissions_path}/only_526_asthma.json"))
      uploads = JSON.parse(File.read("#{submissions_path}/with_uploads.json"))
      json['form526_uploads'] = uploads['form526_uploads']
      json.to_json
    end
  end

  trait :hypertension_and_asthma_claim_for_increase do
    form_json do
      json_string = File.read("#{submissions_path}/only_526_hypertension.json")
      json = JSON.parse json_string
      disabilities = json.dig('form526', 'form526', 'disabilities')
      disabilities.append({
                            'name' => 'Asthma',
                            'classificationCode' => '8935',
                            'disabilityActionType' => 'INCREASE',
                            'ratedDisabilityId' => '1',
                            'diagnosticCode' => 6602,
                            'secondaryDisabilities' => []
                          })
      json.to_json
    end
  end

  trait :hypertension_and_non_rrd_claim_for_increase do
    form_json do
      json_string = File.read("#{submissions_path}/only_526_hypertension.json")
      json = JSON.parse json_string
      disabilities = json.dig('form526', 'form526', 'disabilities')
      disabilities.append({
                            'name' => 'Non-RRD disability',
                            'classificationCode' => '8935',
                            'disabilityActionType' => 'INCREASE',
                            'ratedDisabilityId' => '1',
                            'diagnosticCode' => 1000,
                            'secondaryDisabilities' => []
                          })
      json.to_json
    end
  end

  trait :non_rrd_with_mas_diagnostic_code do
    form_json do
      json_string = File.read("#{submissions_path}/only_526.json")
      json = JSON.parse json_string
      disabilities = json.dig('form526', 'form526', 'disabilities')
      disabilities[0] = {
        'name' => 'Sleep Apnea',
        'disabilityActionType' => 'INCREASE',
        'ratedDisabilityId' => '1',
        'diagnosticCode' => 6847,
        'secondaryDisabilities' => []
      }
      json.to_json
    end
  end

  trait :mas_diagnostic_code_with_classification do
    form_json do
      json_string = File.read("#{submissions_path}/only_526.json")
      json = JSON.parse json_string
      disabilities = json.dig('form526', 'form526', 'disabilities')
      disabilities[0] = {
        'name' => 'Sleep Apnea',
        'classificationCode' => '8935',
        'disabilityActionType' => 'INCREASE',
        'ratedDisabilityId' => '1',
        'diagnosticCode' => 6847,
        'secondaryDisabilities' => []
      }
      json.to_json
    end
  end

  trait :with_multiple_mas_diagnostic_code do
    form_json do
      json_string = File.read("#{submissions_path}/only_526.json")
      json = JSON.parse json_string
      disabilities = json.dig('form526', 'form526', 'disabilities')
      disabilities.push({
                          'name' => 'Sleep Apnea',
                          'classificationCode' => '8935',
                          'disabilityActionType' => 'INCREASE',
                          'ratedDisabilityId' => '2',
                          'diagnosticCode' => 6847,
                          'secondaryDisabilities' => []
                        }, {
                          'name' => 'Rhinitis',
                          'classificationCode' => '8935',
                          'disabilityActionType' => 'INCREASE',
                          'ratedDisabilityId' => '3',
                          'diagnosticCode' => 6522,
                          'secondaryDisabilities' => []
                        })
      json.to_json
    end
  end

  trait :with_mixed_action_disabilities_and_free_text do
    form_json do
      File.read("#{submissions_path}/only_526_mixed_action_disabilities_and_free_text.json")
    end
  end

  trait :with_pact_related_disabilities do
    form_json do
      json_string = File.read("#{submissions_path}/only_526.json")
      json = JSON.parse json_string
      disabilities = json.dig('form526', 'form526', 'disabilities')
      disabilities.push({
                          name: 'hypertension',
                          classificationCode: '3460',
                          disabilityActionType: 'NEW'
                        }, {
                          'name' => 'Rhinitis',
                          'classificationCode' => 'string',
                          'disabilityActionType' => 'INCREASE',
                          'ratedDisabilityId' => '2',
                          'diagnosticCode' => 6522,
                          'secondaryDisabilities' => []
                        })
      json.to_json
    end
  end

  trait :without_diagnostic_code do
    form_json do
      File.read("#{submissions_path}/526_bdd.json")
    end
  end

  # TODO: fix spelling mistakes
  trait :with_one_succesful_job do
    after(:create) do |submission|
      create(:form526_job_status, form526_submission: submission)
    end
  end

  trait :with_multiple_succesful_jobs do
    after(:create) do |submission|
      create(:form526_job_status, form526_submission: submission)
      create(:form526_job_status, job_class: 'SubmitUploads', form526_submission: submission)
    end
  end

  trait :with_mixed_status do
    after(:create) do |submission|
      create(:form526_job_status, form526_submission: submission)
      create(:form526_job_status, :retryable_error, job_class: 'SubmitUploads', form526_submission: submission)
    end
  end

  trait :with_one_failed_job do
    after(:create) do |submission|
      create(:form526_job_status, :retryable_error, form526_submission: submission)
    end
  end

  trait :with_failed_primary_job do
    after(:create) do |submission|
      create(:form526_job_status, :non_retryable_error, form526_submission: submission)
    end
  end

  trait :with_exhausted_primary_job do
    after(:create) do |submission|
      create(:form526_job_status, :pif_in_use_error, form526_submission: submission)
    end
  end

  trait :with_failed_backup_job do
    after(:create) do |submission|
      create(:form526_job_status, :backup_path_job, :non_retryable_error, form526_submission: submission)
    end
  end

  trait :with_exhausted_backup_job do
    after(:create) do |submission|
      create(:form526_job_status, :exhausted_backup_job, form526_submission: submission)
    end
  end

  trait :with_successful_backup_job do
    after(:create) do |submission|
      create(:form526_job_status, :backup_path_job, form526_submission: submission)
    end
  end

  trait :with_pif_in_use_error do
    after(:create) do |submission|
      create(:form526_job_status, :pif_in_use_error, form526_submission: submission)
    end
  end

  trait :with_empty_auth_headers do
    auth_headers_json { { bogus: nil }.to_json }
  end

  trait :with_submitted_claim_id do
    submitted_claim_id { SecureRandom.rand(900_000_000) }
  end

  trait :created_more_than_3_weeks_ago do
    created_at { (3.weeks + 1.day).ago }
  end

  trait :remediated do
    after(:create) do |submission|
      create(:form526_submission_remediation, form526_submission: submission, lifecycle: ['i have been remediated'])
    end
  end

  trait :no_longer_remediated do
    after(:create) do |submission|
      create(:form526_submission_remediation,
             form526_submission: submission,
             lifecycle: ['i am no longer remediated'],
             success: false)
    end
  end

  trait :with_uploads_and_ancillary_forms do
    form_json do
      with_ancillary = JSON.parse(File.read("#{submissions_path}/with_everything.json"))
      with_uploads = JSON.parse(File.read("#{submissions_path}/with_uploads.json"))['form526_uploads']
      with_uploads.each do |upload|
        create(:supporting_evidence_attachment, :with_file_data, guid: upload['confirmationCode'])
      end

      with_ancillary['form526_uploads'] = with_uploads
      with_ancillary.to_json
    end
  end

  trait :with_empty_disabilities do
    form_json do
      File.read("#{submissions_path}/only_526_empty_disabilities.json")
    end
  end
end
