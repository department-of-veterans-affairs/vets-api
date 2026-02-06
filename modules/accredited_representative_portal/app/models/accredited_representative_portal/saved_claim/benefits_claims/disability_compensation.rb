# frozen_string_literal: true

require 'evss/disability_compensation_form/data_translation_all_claim'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/form0781'
require 'evss/disability_compensation_form/form8940'
require 'bgs/disability_compensation_form_flashes'

module AccreditedRepresentativePortal
  module SavedClaim
    class BenefitsClaims
      ##
      # Representative-portal specific SavedClaim for disability compensation forms (Form 526)
      # submitted via the Benefits Claims API.
      #
      # This is distinct from `BenefitsIntake::DisabilityClaim` which uses the
      # Benefits Intake API (deprecated pathway). This class separates representative-submitted
      # claims from veteran-submitted claims for organizational purposes and allows for
      # representative-specific customizations.
      #
      class DisabilityCompensation < ::SavedClaim
        # Use ALLCLAIMS schema which is the actual vets-json-schema for 526 submissions
        # The '21-526EZ' schema doesn't exist, which causes JSONSchemer validation to fail
        FORM_ID = '21-526EZ-ALLCLAIMS'
        FORM = '21-526EZ-ALLCLAIMS'

        attr_accessor :form_hash

        validates :form_id, inclusion: [FORM_ID]

        after_initialize do |_saved_claim|
          self.form_id = FORM_ID
        end

        def self.from_hash(hash)
          saved_claim = new(form: hash['form526'].to_json)
          saved_claim.form_hash = hash
          saved_claim
        end

        ##
        # Translates the form data for submission.
        # Note: For representative submissions, we may not have a full User object,
        # so methods that rely on user attributes need to handle nil values gracefully.
        #
        # @param user [User, nil] The user object (may be nil for rep submissions)
        # @return [String] JSON string of submission data
        #
        def to_submission_data(user)
          form4142 = EVSS::DisabilityCompensationForm::Form4142.new(user, @form_hash.deep_dup).translate
          form526 = @form_hash.deep_dup
          dis_form = EVSS::DisabilityCompensationForm::DataTranslationAllClaim.new(
            user, form526, form4142.present?
          ).translate
          claimed_disabilities = dis_form.dig('form526', 'disabilities')
          form526_uploads = form526['form526'].delete('attachments')

          {
            Form526Submission::FORM_526 => dis_form,
            Form526Submission::FORM_526_UPLOADS => form526_uploads,
            Form526Submission::FORM_4142 => form4142,
            Form526Submission::FORM_0781 => EVSS::DisabilityCompensationForm::Form0781.new(
              user, @form_hash.deep_dup
            ).translate,
            Form526Submission::FORM_8940 => EVSS::DisabilityCompensationForm::Form8940.new(
              user, @form_hash.deep_dup
            ).translate,
            'flashes' => BGS::DisabilityCompensationFormFlashes.new(
              user, @form_hash.deep_dup, claimed_disabilities
            ).translate
          }.to_json
        end

        def display_form_id
          FORM
        end
      end
    end
  end
end