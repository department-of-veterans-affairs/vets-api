# frozen_string_literal: true

require 'evss/disability_compensation_form/data_translation_all_claim'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/form0781'
require 'evss/disability_compensation_form/form8940'

class SavedClaim::DisabilityCompensation < SavedClaim
  alias_attribute :submission, :disability_compensation_submission

  attr_accessor :form_hash

  FORM_526 = 'form526'
  FORM_526_UPLOADS = 'form526_uploads'
  FORM_4142 = 'form4142'
  FORM_0781 = 'form0781'
  FORM_8940 = 'form8940'

  # For backwards compatibility, FORM constant needs to be set
  # subclasses will overwrite this constant when using `add_form_and_validation`
  const_set('FORM', '21-526EZ')

  # Defined for all claims in parent class as `increased only` is being deprecated
  TRANSLATION_CLASS = EVSS::DisabilityCompensationForm::DataTranslationAllClaim

  def self.from_hash(hash)
    saved_claim = new(form: hash['form526'].to_json)
    saved_claim.form_hash = hash
    saved_claim
  end

  # TODO(AJD): this could move to Form526Submission so constants aren't duplicated
  def to_submission_data(user)
    form4142 = EVSS::DisabilityCompensationForm::Form4142.new(user, @form_hash.deep_dup).translate
    form0781 = EVSS::DisabilityCompensationForm::Form0781.new(user, @form_hash.deep_dup).translate
    form8940 = EVSS::DisabilityCompensationForm::Form8940.new(user, @form_hash.deep_dup).translate

    form526 = @form_hash.deep_dup

    form526_uploads = form526['form526'].delete('attachments')

    {
      FORM_526 => translate_data(user, form526, form4142.present?),
      FORM_526_UPLOADS => form526_uploads,
      FORM_4142 => form4142,
      FORM_0781 => form0781,
      FORM_8940 => form8940
    }.to_json
  end

  private

  def translate_data(user, form526, has_form4142)
    self.class::TRANSLATION_CLASS.new(user, form526, has_form4142).translate
  end
end
