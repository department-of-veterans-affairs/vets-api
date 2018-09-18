# frozen_string_literal: true

class GIBillFeedback < Common::RedisStore
  include SetGuid
  include AsyncRequest

  attr_accessor(:user)
  attr_accessor(:form)

  FORM_ID = 'FEEDBACK-TOOL'

  redis_store REDIS_CONFIG['gi_bill_feedback']['namespace']
  redis_ttl REDIS_CONFIG['gi_bill_feedback']['each_ttl']
  redis_key(:guid)

  attribute(:state, String, default: 'pending')
  attribute(:guid, String)
  attribute(:response, String)

  alias id guid

  validate(:form_matches_schema, unless: :persisted?)
  validates(:form, presence: true, unless: :persisted?)

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def parsed_response
    return if response.blank?
    @parsed_response ||= JSON.parse(response)
  end

  def get_school_details(facility_code)
    attributes = GI::Client.new.get_institution_details(id: facility_code)[:data][:attributes]

    {
      'name' => attributes[:name],
      'address' => {
        'street' => [attributes[:address_1], attributes[:address_2]].compact.join(' '),
        'street2' => attributes[:address_3],
        'city' => attributes[:city],
        'postal_code' => attributes[:zip],
        'state' => attributes[:state],
        'country' => attributes[:country]
      }
    }
  end

  def get_user_details
    profile_data = {}

    if user.present?
      va_profile = user.va_profile
      profile_data = {
        'active_ICN' => user.icn,
        'historical_ICN' => va_profile&.historical_icns,
        'sec_ID' => va_profile&.sec_id,
        'SSN' => user.ssn
      }
    end

    { 'profile_data' => profile_data }
  end

  def transform_form
    transformed = parsed_form.deep_transform_keys(&:underscore)
    transformed['affiliation'] = transformed.delete('service_affiliation')
    transformed.delete('service_date_range').tap do |service_date_range|
      next if service_date_range.blank?
      transformed['entered_duty'] = service_date_range['from']
      transformed['release_from_duty'] = service_date_range['to']
    end

    transformed.merge!(get_user_details)

    transformed['education_details'].tap do |education_details|
      next if education_details.blank?
      facility_code = education_details.delete('facility_code')
      education_details['school'] = get_school_details(facility_code) if facility_code.present?
      %w[programs assistance].each do |key|
        education_details[key] = transform_keys_into_array(parsed_form['educationDetails'][key])
      end
    end

    transformed['issue'] = transform_keys_into_array(transformed['issue'])
    transformed['email'] = transformed.delete('anonymous_email') || transformed.delete('applicant_email')

    transformed
  end

  def save
    originally_persisted = @persisted
    saved = super

    create_submission_job if saved && !originally_persisted

    saved
  end

  private

  def anonymous?
    parsed_form['onBehalfOf'] == 'Anonymous'
  end

  def transform_keys_into_array(hash)
    return [] if hash.blank?

    hash.keep_if { |_, v| v.present? }.keys
  end

  def form_matches_schema
    if form.present?
      errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM_ID], parsed_form))
    end
  end

  def create_submission_job
    user_uuid = anonymous? ? nil : user&.uuid
    GIBillFeedbackSubmissionJob.perform_async(id, form, user_uuid)
  end
end
