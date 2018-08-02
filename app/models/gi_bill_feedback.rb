class GIBillFeedback < Common::RedisStore
  include SetGuid
  include AsyncRequest

  attr_accessor(:user)
  attr_accessor(:form)

  FORM_ID = 'complaint-tool'

  redis_store REDIS_CONFIG['gi_bill_feedback']['namespace']
  redis_ttl REDIS_CONFIG['gi_bill_feedback']['each_ttl']
  redis_key(:guid)

  attribute(:state, String, default: 'pending')
  attribute(:guid, String)
  attribute(:response, String)

  alias_method(:id, :guid)

  validate(:form_matches_schema, unless: :persisted?)
  validates(:form, presence: true, unless: :persisted?)

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def parsed_response
    return if response.blank?
    @parsed_response ||= JSON.parse(response)
  end

  def transform_form
    transformed = parsed_form.deep_transform_keys{ |k| k.underscore }
    transformed['affiliation'] = transformed.delete('service_affiliation')
    transformed.delete('service_date_range').tap do |service_date_range|
      next if service_date_range.blank?
      transformed['entered_duty'] = service_date_range['from']
      transformed['release_from_duty'] = service_date_range['to']
    end

    user&.va_profile.tap do |va_profile|
      next if va_profile.blank?
    end

    if user.present?
      va_profile = user.va_profile
      transformed['profile_data'] = {
        'active_ICN' => user.icn,
        'historical_ICN' => va_profile&.historical_icns,
        'sec_ID' => va_profile&.sec_id,
        'SSN' => user.ssn
      }
    end

    transformed['education_details'].tap do |education_details|
      next if education_details.blank?
      # TODO set school address from facility code
      %w[programs assistance].each do |key|
        education_details[key] = transform_keys_into_array(parsed_form['educationDetails'][key])
      end
    end

    transformed['issue'] = transform_keys_into_array(transformed['issue'])
    transformed['email'] = transformed.delete('anonymous_email') || transformed.delete('applicant_email')

    binding.pry; fail
    transformed
  end

  def save
    originally_persisted = @persisted
    saved = super

    if saved && !originally_persisted
      create_submission_job
    end

    saved
  end

  private

  def transform_keys_into_array(hash)
    array = []
    return array if hash.blank?

    hash.each do |k, v|
      array << k if v
    end

    array
  end

  def form_matches_schema
    if form.present?
      errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM_ID], parsed_form))
    end
  end

  def create_submission_job
    puts 'soubmission job'
    # binding.pry; fail
    # SubmissionJob.perform_async(id, form, user&.uuid)
  end
end
