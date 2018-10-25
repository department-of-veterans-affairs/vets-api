# frozen_string_literal: true

class GIBillFeedback < Common::RedisStore
  include RedisForm

  FORM_ID = 'FEEDBACK-TOOL'

  def get_user_details
    profile_data = {}

    if user.present?
      va_profile = user.va_profile
      profile_data = {
        'active_ICN' => user.icn,
        'historical_ICN' => va_profile&.historical_icns,
        'sec_ID' => va_profile&.sec_id
      }
    end

    { 'profile_data' => profile_data }
  end

  # rubocop:disable Metrics/MethodLength
  def transform_form
    transformed = parsed_form.deep_transform_keys(&:underscore)
    transformed.delete('privacy_agreement_accepted')
    transformed['affiliation'] = transformed.delete('service_affiliation')
    transformed.delete('service_date_range').tap do |service_date_range|
      next if service_date_range.blank?
      transformed['entered_duty'] = service_date_range['from']
      transformed['release_from_duty'] = service_date_range['to']
    end

    transformed.merge!(get_user_details)
    if transformed['social_security_number_last_four'].present?
      transformed['profile_data']['SSN'] = transformed.delete('social_security_number_last_four')
    end

    transformed['education_details'].tap do |education_details|
      school = education_details['school']

      transformed['facility_code'] = school.delete('facility_code')

      transform_school_address(school['address'])
      %w[programs assistance].each do |key|
        education_details[key] = transform_keys_into_array(parsed_form['educationDetails'][key])
      end
    end

    transformed['issue'] = transform_keys_into_array(transformed['issue'])
    transformed['email'] = transformed.delete('anonymous_email') || transformed.delete('applicant_email')
    transformed = Common::HashHelpers.deep_compact(transformed)
    transformed.delete('profile_data') if transformed['profile_data'].blank?

    transformed
  end
  # rubocop:enable Metrics/MethodLength

  private

  def transform_school_address(address)
    return if address['street3'].blank?
    address['street'] = [address['street'], address['street2']].compact.join(', ')
    address['street2'] = address.delete('street3')
  end

  def anonymous?
    parsed_form['onBehalfOf'] == 'Anonymous'
  end

  def transform_keys_into_array(hash)
    return [] if hash.blank?

    hash.keep_if { |_, v| v.present? }.keys
  end

  def create_submission_job
    user_uuid = anonymous? ? nil : user&.uuid
    GIBillFeedbackSubmissionJob.perform_async(id, form, user_uuid)
  end
end
