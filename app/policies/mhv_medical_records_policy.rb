# frozen_string_literal: true

require 'medical_records/user_eligibility/client'

MHVMedicalRecordsPolicy = Struct.new(:user, :mhv_medical_records) do
  MR_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
    client = UserEligibility::Client.new(session: { user_id: user.mhv_correlation_id, icn: user.icn })
    response = client.get_is_valid_sm_user
  rescue
    MR_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
  else
    validate_client(response) && user.va_patient
  end

  private

  def validate_client(response)
    [
      'MHV Premium SM account with no logins  in past 26 months',
      'MHV Premium SM account with Logins in past 26 months',
      'MHV Premium account with no SM'
    ].any? { |substring| response.include?(substring) }
  rescue
    log_denial_details
    false
  end

  def log_denial_details
    Rails.logger.info('MR ACCESS DENIED IN USER ELIGIBILITY POLICY',
                      mhv_id: user.mhv_correlation_id.presence || 'false',
                      sign_in_service: user.identity.sign_in[:service_name],
                      va_facilities: user.va_treatment_facility_ids.length,
                      va_patient: user.va_patient?)
  end
end
