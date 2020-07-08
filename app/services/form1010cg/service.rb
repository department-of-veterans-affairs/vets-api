# frozen_string_literal: true

# This service manages the interactions between CaregiversAssistanceClaim, CARMA, and Form1010cg::Submission.
module Form1010cg
  class Service
    class InvalidVeteranStatus < StandardError
    end

    attr_accessor :claim, # SavedClaim::CaregiversAssistanceClaim
                  :submission # Form1010cg::Submission

    NOT_FOUND = 'NOT_FOUND'

    def initialize(claim, submission = nil)
      # This service makes assumptions on what data is present on the claim
      # Make sure the claim is valid, so we can be assured the required data is present.
      claim.valid? || raise(Common::Exceptions::ValidationErrors, claim)

      # The CaregiversAssistanceClaim we are processing with this service
      @claim        = claim
      @submission   = submission

      # Store for the search results we will run on MVI and eMIS
      @cache = {
        # [form_subject]: String          - The person's ICN
        # [form_subject]: NOT_FOUND       - This person could not be found in MVI
        # [form_subject]: nil             - An MVI search has not been conducted for this person
        icns: {},
        # [form_subject]: true            - This person is a veteran
        # [form_subject]: false           - This person's veteran status cannot be confirmed
        # [form_subject]: nil             - An eMIS search has not been conducted for this person
        veteran_statuses: {}
      }
    end

    # Will submit the claim to CARMA.
    #
    # @return [Form1010cg::Submission]
    def process_claim!
      raise 'submission already present' if submission.present?

      assert_veteran_status

      carma_submission = CARMA::Models::Submission.from_claim(claim, build_metadata).submit!

      @submission = Form1010cg::Submission.new(
        carma_case_id: carma_submission.carma_case_id,
        submitted_at: carma_submission.submitted_at
      )

      submit_attachment

      submission
    end

    # Will generate a PDF version of the submission and attach it to the CARMA Case.
    #
    # @return [Boolean]
    def submit_attachment # rubocop:disable Metrics/MethodLength
      raise 'requires a processed submission'     if  submission&.carma_case_id.blank?
      raise 'submission already has attachments'  if  submission.attachments.any?

      file_path = begin
                    claim.to_pdf
                  rescue
                    return false
                  end

      begin
        carma_attachments = CARMA::Models::Attachments.new(
          submission.carma_case_id,
          claim.veteran_data['fullName']['first'],
          claim.veteran_data['fullName']['last']
        )

        carma_attachments.add(CARMA::Models::Attachment::DOCUMENT_TYPES['10-10CG'], file_path)

        carma_attachments.submit!
        submission.attachments = carma_attachments.to_hash
      rescue
        # The end-user doesn't know an attachment is being sent with the submission at all. The PDF we're
        # sending to CARMA is just the submission, itself, as a PDF. This is to follow the current
        # conventions of CARMA: every case has the PDF of the submission attached.
        #
        # Regardless of the reason, we shouldn't raise an error when sending attachments fails.
        # It's non-critical and we don't want the error to bubble up to the response,
        # misleading the user to think thier claim was not submitted.
        #
        # If we made it this far, there is a submission that exists in CARMA.
        # So the user should get a sucessful response, whether attachments reach CARMA or not.
        File.delete(file_path)
        return false
      end

      File.delete(file_path)
      true
    end

    # Will raise an error unless the veteran specified on the claim's data can be found in MVI
    #
    # @return [nil]
    def assert_veteran_status
      raise InvalidVeteranStatus if icn_for('veteran') == NOT_FOUND
    end

    # Returns a metadata hash:
    #
    # {
    #   veteran: {
    #     is_veteran: true | false | nil,
    #     icn: String | nil
    #   },
    #   primaryCaregiver: { icn: String | nil },
    #   secondaryCaregiverOne?: { icn: String | nil },
    #   secondaryCaregiverTwo?: { icn: String | nil }
    # }
    def build_metadata
      # Set the ICN's for each form_subject on the metadata hash
      metadata = claim.form_subjects.each_with_object({}) do |form_subject, obj|
        icn = icn_for(form_subject)

        obj[form_subject.snakecase.to_sym] = {
          icn: icn == NOT_FOUND ? nil : icn
        }
      end

      metadata[:veteran][:is_veteran] = is_veteran('veteran')

      metadata
    end

    # Will search MVI for the provided form subject and return (1) the matching profile's ICN or (2) `NOT_FOUND`.
    # The result will be cached and subsequent calls will return the cached value, preventing additional api requests.
    #
    # @param form_subject [String] The key in the claim's data that contains this person's info (ex: "veteran")
    # @return [String | NOT_FOUND] Returns the icn of the form subject if found, and NOT_FOUND otherwise.
    def icn_for(form_subject)
      cached_icn = @cache[:icns][form_subject]
      return cached_icn unless cached_icn.nil?

      response = mvi_service.find_profile(build_user_identity_for(form_subject))

      case response.status
      when 'OK'
        return @cache[:icns][form_subject] = response.profile.icn
      when 'NOT_FOUND'
        return @cache[:icns][form_subject] = NOT_FOUND
      end

      raise response.error if response.error

      @cache[:icns][form_subject] = NOT_FOUND
    end

    # Will search eMIS for the provided form subject and return `true` if the subject is a verteran.
    # The result will be cached and subsequent calls will return the cached value, preventing additional api requests.
    #
    # @param form_subject [String] The key in the claim's data that contains this person's info (ex: "veteran")
    # @return [true | false] Returns `true` if the form subject is a veteran and false otherwise.
    def is_veteran(form_subject) # rubocop:disable Naming/PredicateName
      cached_veteran_status = @cache[:veteran_statuses][form_subject]
      return cached_veteran_status unless cached_veteran_status.nil?

      icn = icn_for(form_subject)
      return @cache[:veteran_statuses][form_subject] = false if icn == NOT_FOUND

      response = EMIS::VeteranStatusService.new.get_veteran_status(icn: icn)

      is_veteran = response&.items&.first&.title38_status_code == 'V1'

      @cache[:veteran_statuses][form_subject] = is_veteran || false
    end

    private

    def mvi_service
      @mvi_service ||= MVI::Service.new
    end

    # MVI::Service requires a valid UserIdentity to run a search, but only reads the user's attributes.
    # This method will build a valid UserIdentity, so MVI::Service can pluck the name, ssn, dob, and gender.
    #
    # @param form_subject [String] The key in the claim's data that contains this person's info (ex: "veteran")
    # @return [UserIdentity] A valid UserIdentity for the given form_subject
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
