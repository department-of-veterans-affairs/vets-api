# frozen_string_literal: true

class SavedClaim::DisabilityCompensation < SavedClaim
  has_one :disability_compensation_submission,
          class_name: 'DisabilityCompensationSubmission',
          inverse_of: :disability_compensation_claim,
          dependent: :destroy

  has_one :async_transaction,
          through: :disability_compensation_submission,
          source: :disability_compensation_job

  alias_attribute :submission, :disability_compensation_submission

  add_form_and_validation('21-526EZ')

  attr_writer :form_hash

  def self.from_hash(hash)
    saved_claim = new(form: hash['form526'].to_json)
    saved_claim.form_hash = hash
    saved_claim
  end

  def to_submission_data(user)
    form526 = @form_hash.deep_dup
    form526_uploads = form526['form526'].delete('attachments')
    form4142 = @form_hash.deep_dup
    {
      'form526' => EVSS::DisabilityCompensationForm::DataTranslation.new(user, form526).translate,
      'form526_uploads' => form526_uploads,
      'form4142' => EVSS::DisabilityCompensationForm::Form4142.new(user, form4142).translate
    }
  end
end
