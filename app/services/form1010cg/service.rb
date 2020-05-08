# frozen_string_literal: true

# This service manages the interactions between CaregiversAssistanceClaim, CARMA, and Form1010cg::Submission.
module Form1010cg
  class Service
    attr_reader :claim

    NOT_FOUND = 'NOT_FOUND'

    def initialize(claim)
      claim.valid? || raise(Common::Exceptions::ValidationErrors, claim)

      @claim = claim
      @cached_icns = {}
    end

    def process_claim!
      assert_veteran_status

      carma_submission = CARMA::Models::Submission.from_claim(claim, build_metadata).submit!

      Form1010cg::Submission.new(
        carma_case_id: carma_submission.carma_case_id,
        submitted_at: carma_submission.submitted_at
      )
    end

    def assert_veteran_status
      raise_unprocessable if icn_for('veteran') == NOT_FOUND
    end

    def build_metadata
      claim.form_subjects.each_with_object({}) do |form_subject, metadata|
        icn = icn_for(form_subject)
        metadata[form_subject.to_sym] = {
          icn: icn == NOT_FOUND ? nil : icn
        }
      end
    end

    def icn_for(form_subject)
      cached_icn = @cached_icns[form_subject]
      return cached_icn unless cached_icn.nil?

      begin
        response = mvi_service.find_profile(build_user_identity_for(form_subject))
      rescue MVI::Errors::RecordNotFound
        return @cached_icns[form_subject] = NOT_FOUND
      end

      @cached_icns[form_subject] = response&.profile&.icn if response&.status == 'OK'
    end

    private

    def raise_unprocessable
      message = 'Unable to process submission digitally'
      claim.errors.add(:base, message, message: message)
      raise(Common::Exceptions::ValidationErrors, claim)
    end

    def mvi_service
      @mvi_service ||= MVI::Service.new
    end

    def build_user_identity_for(form_subject)
      data = claim.parsed_form[form_subject]

      attributes = {
        first_name: data['fullName']['first'],
        middle_name: data['fullName']['middle'],
        last_name: data['fullName']['last'],
        birth_date: data['dateOfBirth'],
        gender: data['gender'] == 'U' ? nil : data['gender'],
        ssn: data['ssnOrTin'],
        email: data['email'] || 'no-email@example.com',
        uuid: SecureRandom.uuid,
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      }

      UserIdentity.new attributes
    end
  end
end
