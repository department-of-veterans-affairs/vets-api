# frozen_string_literal: true

require 'medical_records/user_eligibility/client'

MHVMedicalRecordsPolicy = Struct.new(:user, :mhv_medical_records) do
  MR_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
    if Flipper.enabled?(:mhv_medical_records_new_eligibility_check)
      client = UserEligibility::Client.new(session: { user_id: user.mhv_correlation_id, icn: user.icn })

      begin
        response = client.get_is_valid_sm_user
        validate_client(response) && user.va_patient?
      rescue => e
        log_denial_details('ERROR FETCHING SM USER ELIGIBILITY', e)
        false
      end
    else
      MR_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
    end
  end

  private

  def validate_client(response)
    [
      'MHV Premium SM account with no logins  in past 26 months',
      'MHV Premium SM account with Logins in past 26 months',
      'MHV Premium account with no SM'
    ].any? { |substring| response.include?(substring) }
  rescue => e
    log_denial_details('MR ACCESS DENIED IN USER ELIGIBILITY POLICY', e)
    false
  end

  def log_denial_details(message, error)
    Rails.logger.info(message,
                      mhv_id: user.mhv_correlation_id.presence || 'false',
                      sign_in_service: user.identity.sign_in[:service_name],
                      va_facilities: user.va_treatment_facility_ids.length,
                      va_patient: user.va_patient?,
                      message: error.message)
  end
end
