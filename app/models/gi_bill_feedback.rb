# frozen_string_literal: true

class GIBillFeedback < Common::RedisStore
  include RedisForm

  FORM_ID = 'FEEDBACK-TOOL'

  FEEDBACK_MAPPINGS = {
    'post9::11 ch 33' => 'Post-9/11 Ch 33',
    'chapter33' => 'Post-9/11 Ch 33',
    'mGIBAd ch 30' => 'MGIB-AD Ch 30',
    'chapter30' => 'MGIB-AD Ch 30',
    'mGIBSr ch 1606' => 'MGIB-SR Ch 1606',
    'chapter1606' => 'MGIB-SR Ch 1606',
    'tatu' => 'TATU',
    'reap' => 'REAP',
    'dea ch 35' => 'DEA Ch 35',
    'chapter35' => 'DEA Ch 35',
    'vre ch 31' => 'VRE Ch 31',
    'chapter31' => 'VRE Ch 31',
    'ta' => 'TA',
    'taAgr' => 'TA-AGR',
    'myCaa' => 'MyCAA',
    'ffa' => 'FFA'
  }.freeze

  def get_user_details
    profile_data = {}

    if user.present?
      profile_data = {
        'active_ICN' => user.icn,
        'sec_ID' => user.sec_id
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

    transformed['education_details'].tap do |education_details|
      school = education_details['school']

      transformed['facility_code'] = school.delete('facility_code')

      transform_school_address(school['address'])
      %w[programs assistance].each do |key|
        options_hash = fix_options(parsed_form['educationDetails'][key], key)
        education_details[key] = transform_keys_into_array(options_hash)
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

  def fix_options(options_hash, key)
    # if user saves form with options, then goes back to the page
    # and fills out options again, then the hash will contain both malformed and
    # normal option keys
    keys_size = options_hash.keys.size

    max_size = VetsJsonSchema::SCHEMAS[FORM_ID]['properties'][
      'educationDetails'
    ]['properties'][key]['properties'].size

    return remove_malformed_options(options_hash) if keys_size > max_size

    transform_malformed_options(options_hash)
  end

  def remove_malformed_options(options_hash)
    options_hash.except(*FEEDBACK_MAPPINGS.keys)
  end

  def transform_malformed_options(options_hash)
    return_val = {}

    options_hash.each do |k, v|
      FEEDBACK_MAPPINGS[k].tap do |new_key|
        if new_key.blank?
          return_val[k] = v
        else
          return_val[new_key] = v
        end
      end
    end

    return_val
  end

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

    hash.compact_blank!.keys
  end

  def create_submission_job
    user_uuid = anonymous? ? nil : user&.uuid
    GIBillFeedbackSubmissionJob.perform_async(id, form, user_uuid)
  end
end
