# frozen_string_literal: true

# Remediation seeds for simple_forms_api tasks (local development)
# Creates multiple Form526Submission entries with varied content/dates

# Shared test user_account for all seeds
test_icn = 'seed_remediation_test'
user_account = UserAccount.find_or_create_by!(icn: test_icn)

# Clear existing remediation records to avoid conflicts
Form526Submission.where(id: 1..6).destroy_all
Rails.logger.debug '[Seeds] Cleared existing remediation test records (1..6)'

# Flat structure for pre-2019 submissions
flat_pre_structure = { 'form0781' => { 'incidents' => [] } }

# Nested structure for post-2019 submissions
nested_structure = {
  'form0781' => {
    'form0781' => { 'incidents' => [] },
    'form0781v2' => { 'incidents' => [] }
  }
}

test_cases = []

# Case 1: Pre-2019-06-24
case1 = Marshal.load(Marshal.dump(flat_pre_structure))
case1['form0781']['incidents'] = [
  {
    'incidentDate' => '2018-01-01',
    'incidentDescription' => 'Pre-threshold case - only 0781',
    'unitAssigned' => 'Unit1',
    'unitAssignedDates' => { 'from' => '2018-01-01', 'to' => '2018-01-02' }
  }
]
test_cases << { id: 1, date: Date.new(2018, 1, 1), form_json: case1 }

# Case 2: Post-2019-06-24
case2 = Marshal.load(Marshal.dump(nested_structure))
case2['form0781']['form0781']['incidents'] = [
  {
    'incidentDate' => '2020-01-01',
    'incidentDescription' => 'Post-threshold both forms 0781',
    'unitAssigned' => 'Unit2',
    'unitAssignedDates' => { 'from' => '2020-01-01', 'to' => '2020-01-02' }
  }
]
case2['form0781']['form0781v2']['incidents'] = [
  {
    'incidentDate' => '2020-01-01',
    'incidentDescription' => 'Post-threshold 0781v2',
    'unitAssigned' => 'Unit2v2',
    'unitAssignedDates' => { 'from' => '2020-01-01', 'to' => '2020-01-02' }
  }
]
test_cases << { id: 2, date: Date.new(2020, 1, 1), form_json: case2 }

# Case 3: Post-2019-06-24 only v2
# For only v2, start from nested structure and leave v1 blank
case3 = Marshal.load(Marshal.dump(nested_structure))
# v1 blank, v2 has
case3['form0781']['form0781v2']['incidents'] = [
  {
    'incidentDate' => '2021-02-02',
    'incidentDescription' => 'Only 0781v2 content',
    'unitAssigned' => 'Unit3v2',
    'unitAssignedDates' => { 'from' => '2021-02-02', 'to' => '2021-02-03' }
  }
]
test_cases << { id: 3, date: Date.new(2021, 2, 2), form_json: case3 }

# Cases 4–6: blank (skip)
(4..6).each do |i|
  blank = Marshal.load(Marshal.dump(nested_structure))
  test_cases << { id: i, date: Time.zone.today, form_json: blank }
end

# Create seeds

test_cases.each do |tc|
  # Saved claim stub
  saved = SavedClaim::DisabilityCompensation.new(
    user_account_id: user_account.id,
    form_id: '21-526EZ',
    form: { 'seed' => tc[:id] }.to_json
  )
  saved.save!(validate: false)

  submission = Form526Submission.create!(
    id: tc[:id],
    user_uuid: user_account.id,
    user_account_id: user_account.id,
    saved_claim_id: saved.id,
    auth_headers_json: { 'va_eauth_dodedipnid' => 'seed' }.to_json,
    form_json: tc[:form_json].to_json,
    created_at: tc[:date].to_time,
    updated_at: tc[:date].to_time
  )

  # Log what's in each form for debugging
  if tc[:date] < Date.new(2019, 6, 24)
    # Flat Pre-2019-06-24 structure
    form0781_incidents = tc[:form_json]['form0781']['incidents']&.size || 0
    form0781v2_incidents = 0
  else
    # Nested Post-2019-06-24 structure
    nested = tc[:form_json]['form0781']
    form0781_incidents = nested['form0781']['incidents']&.size || 0
    form0781v2_incidents = nested['form0781v2']['incidents']&.size || 0
  end

  Rails.logger.debug { "[Seeds] Created Form526Submission id=#{submission.id} date=#{tc[:date]}" }
  Rails.logger.debug { "  - form0781: #{form0781_incidents} incidents" }
  Rails.logger.debug { "  - form0781v2: #{form0781v2_incidents} incidents" }
end

Rails.logger.debug '[Seeds] Remediation seeds loaded.'
