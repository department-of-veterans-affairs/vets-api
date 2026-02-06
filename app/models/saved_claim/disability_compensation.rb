# frozen_string_literal: true

require 'evss/disability_compensation_form/data_translation_all_claim'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/form0781'
require 'evss/disability_compensation_form/form8940'
require 'bgs/disability_compensation_form_flashes'

class SavedClaim::DisabilityCompensation < SavedClaim
  attr_accessor :form_hash

  # For backwards compatibility, FORM constant needs to be set
  # subclasses will overwrite this constant when using `add_form_and_validation`
  const_set('FORM', '21-526EZ')

  def self.from_hash(hash)
    saved_claim = new(form: hash['form526'].to_json)
    saved_claim.form_hash = hash
    saved_claim
  end

  def to_submission_data(user)
    form4142 = EVSS::DisabilityCompensationForm::Form4142.new(user, @form_hash.deep_dup).translate
    form526 = @form_hash.deep_dup
    dis_form = EVSS::DisabilityCompensationForm::DataTranslationAllClaim.new(user, form526, form4142.present?).translate
    claimed_disabilities = dis_form.dig('form526', 'disabilities')
    form526_uploads = form526['form526'].delete('attachments')

    {
      Form526Submission::FORM_526 => dis_form,
      Form526Submission::FORM_526_UPLOADS => form526_uploads,
      Form526Submission::FORM_4142 => form4142,
      Form526Submission::FORM_0781 => EVSS::DisabilityCompensationForm::Form0781.new(user,
                                                                                     @form_hash.deep_dup).translate,
      Form526Submission::FORM_8940 => EVSS::DisabilityCompensationForm::Form8940.new(user,
                                                                                     @form_hash.deep_dup).translate,
      'flashes' => BGS::DisabilityCompensationFormFlashes.new(user, @form_hash.deep_dup,
                                                              claimed_disabilities).translate
    }.to_json
  end
end
