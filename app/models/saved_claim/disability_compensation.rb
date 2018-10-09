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
    form4142 = EVSS::DisabilityCompensationForm::Form4142.new(user, @form_hash).translate
    # if form4142
    #   @form_hash['form526']['overflowText'] = 'VA Form 21-4142/4142a has been completed by the applicant and sent to the PMR contractor for processing in accordance with M21-1 III.iii.1.D.2.'
    # end

    {
      'form_4142' => form4142,
      'form_526' => EVSS::DisabilityCompensationForm::DataTranslation.new(
        user, @form_hash.except('attachments')
      ).translate,
      'form_526_uploads' => @form_hash.dig('form526', 'attachments')
    }
  end
end
