# frozen_string_literal: true

require 'vets/shared_logging'

module VRE
  class VREVeteranReadinessEmploymentClaim < ::SavedClaim
    include Vets::SharedLogging

    FORM = Constants::FORM
    VBMS_CONFIRMATION = :confirmation_vbms
    LIGHTHOUSE_CONFIRMATION = :confirmation_lighthouse
    CONFIRMATION_EMAIL_TEMPLATES = {
      VBMS_CONFIRMATION => Settings.vanotify.services.veteran_readiness_and_employment
                                   .email.confirmation_vbms.template_id,
      LIGHTHOUSE_CONFIRMATION => Settings.vanotify.services.veteran_readiness_and_employment
                                         .email.confirmation_lighthouse.template_id
    }.freeze

    def initialize(args)
      @sent_to_lighthouse = false
      super
    end

    def add_claimant_info(user)
      if form.blank?
        Rails.logger.info('VRE claim form is blank, skipping adding veteran info', { user_uuid: user&.uuid })
        return
      end

      updated_form = parsed_form

      add_veteran_info(updated_form, user) if user&.loa3?
      add_office_location(updated_form) if updated_form['veteranInformation'].present?

      update!(form: updated_form.to_json)
    end

    def add_veteran_info(updated_form, user)
      updated_form['veteranInformation'].merge!(
        {
          'VAFileNumber' => veteran_va_file_number(user),
          'pid' => user.participant_id,
          'edipi' => user.edipi,
          'vet360ID' => user.vet360_id,
          'dob' => user.birth_date,
          'ssn' => user.ssn
        }
      ).except!('vaFileNumber')
    end

    # Common method for VRE form submission:
    # * Adds information from user to payload
    # * Submits to VBMS if participant ID is there, to Lighthouse if not.
    # * Sends email if user is present
    # * Sends to RES service
    # @param user [User] user account of submitting user
    # @return [Hash] Response payload of service that was used (RES)
    def send_to_vre(user)
      add_claimant_info(user)

      if user&.participant_id
        upload_to_vbms(user:)
      else
        Rails.logger.warn('Participant id is blank when submitting VRE claim, sending to Lighthouse',
                          { user_uuid: user&.uuid })
        send_to_lighthouse!(user)
      end

      email_addr = Constants::REGIONAL_OFFICE_EMAILS[@office_location] || 'VRE.VBACO@va.gov'
      Rails.logger.info('VRE claim sending email:', { email: email_addr, user_uuid: user&.uuid })
      VRE::VeteranReadinessEmploymentMailer.build(user.participant_id, email_addr,
                                                  @sent_to_lighthouse).deliver_later

      send_to_res(user)
    end

    # Submit claim into VBMS service, uploading document directly to VBMS,
    # adds document ID from VBMS to form info, and sends confirmation email to user
    # Submits to Lighthouse on failure
    # @param user [User] user account of submitting user
    # @return None
    def upload_to_vbms(user:, doc_type: '1167')
      form_path = PdfFill::Filler.fill_form(self, nil, { created_at: })

      uploader = ::ClaimsApi::VBMSUploader.new(
        filepath: Rails.root.join(form_path),
        file_number: parsed_form['veteranInformation']['VAFileNumber'] || parsed_form['veteranInformation']['ssn'],
        doc_type:
      )

      log_to_statsd('vbms') do
        Rails.logger.info('Uploading VRE claim to VBMS', { user_uuid: user&.uuid })
        response = uploader.upload!

        if response[:vbms_document_series_ref_id].present?
          updated_form = parsed_form
          updated_form['documentId'] = response[:vbms_document_series_ref_id]
          update!(form: updated_form.to_json)
        end
      end

      !Flipper.enabled?(:vre_use_new_vfs_notification_library) &&
        send_vbms_lighthouse_confirmation_email('VBMS', CONFIRMATION_EMAIL_TEMPLATES[VBMS_CONFIRMATION], user)
    rescue => e
      Rails.logger.error('Error uploading VRE claim to VBMS.', { user_uuid: user&.uuid, message: e.message })
      send_to_lighthouse!(user)
    end

    def to_pdf(file_name = nil)
      PdfFill::Filler.fill_form(self, file_name, { created_at: })
    end

    # Submit claim into lighthouse service, adds veteran info to top level of form,
    # and sends confirmation email to user
    # @param user [User] user account of submitting user
    # @return None
    def send_to_lighthouse!(user)
      form_copy = parsed_form.clone

      form_copy['veteranSocialSecurityNumber'] = parsed_form.dig('veteranInformation', 'ssn')
      form_copy['veteranFullName'] = parsed_form.dig('veteranInformation', 'fullName')
      form_copy['vaFileNumber'] = parsed_form.dig('veteranInformation', 'VAFileNumber')

      unless form_copy['veteranSocialSecurityNumber']
        if user&.loa3?
          Rails.logger.warn('VRE: No SSN found for LOA3 user', { user_uuid: user&.uuid })
        else
          Rails.logger.info('VRE: No SSN found for LOA1 user', { user_uuid: user&.uuid })
        end
      end

      update!(form: form_copy.to_json)

      process_attachments!
      @sent_to_lighthouse = true

      !Flipper.enabled?(:vre_use_new_vfs_notification_library) &&
        send_vbms_lighthouse_confirmation_email('Lighthouse', CONFIRMATION_EMAIL_TEMPLATES[LIGHTHOUSE_CONFIRMATION],
                                                user)
    rescue => e
      Rails.logger.error('Error uploading VRE claim to Benefits Intake API', { user_uuid: user&.uuid, e: })
      raise
    end

    # SavedClaims require regional_office to be defined
    def regional_office
      []
    end

    # Lighthouse::SubmitBenefitsIntakeClaim will call the function `send_confirmation_email` (if it exists).
    # Do not name a function `send_confirmation_email`, unless it accepts 0 arguments.
    def send_vbms_lighthouse_confirmation_email(service, email_template, user)
      if email.blank?
        Rails.logger.warn("#{service} confirmation email not sent: parsed form missing email.",
                          { user_uuid: user&.uuid })
        return
      end

      VANotify::EmailJob.perform_async(
        email,
        email_template,
        {
          'first_name' => parsed_form.dig('veteranInformation', 'fullName', 'first'),
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      )
      Rails.logger.info("VRE #{service} upload successful. #{service} confirmation email sent.")
    end

    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = ::PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }

      Rails.logger.info('VRE claim submitting to Benefits Intake API')
      ::Lighthouse::SubmitBenefitsIntakeClaim.new.perform(id)
    end

    def business_line
      'VRE'
    end

    def email
      @email ||= parsed_form['email']
    end

    # this failure email is not the ideal way to handle the Notification Emails as
    # part of the ZSF work, but with the initial timeline it handles the email as intended.
    # Future work will be integrating into the Va Notify common lib:
    # https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/veteran_facing_services/notification_email.rb
    def send_failure_email(email)
      if email.present?
        ::VANotify::EmailJob.perform_async(
          email,
          Settings.vanotify.services.va_gov.template_id.form1900_action_needed_email,
          {
            'first_name' => parsed_form.dig('veteranInformation', 'fullName', 'first'),
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          }
        )
      else
        Rails.logger.warn('VRE claim failure email not sent: email not present.')
      end
    end

    private

    # Send claim via RES service
    # @param user [User] user account of submitting user
    # @return [Hash] Response payload of RES service
    def send_to_res(user)
      Rails.logger.info('VRE claim sending to RES service',
                        {
                          user_uuid: user&.uuid,
                          was_sent: @sent_to_lighthouse,
                          user_present: user.present?
                        })

      service = VRE::Ch31Form.new(user:, claim: self)
      service.submit
    end

    def add_office_location(updated_form)
      regional_office = check_office_location
      @office_location = regional_office[0]
      office_name = regional_office[1]

      updated_form['veteranInformation'].merge!({
                                                  'regionalOffice' => "#{@office_location} - #{office_name}",
                                                  'regionalOfficeName' => office_name,
                                                  'stationId' => @office_location
                                                })
    end

    def check_office_location
      service = bgs_client
      vet_info = parsed_form['veteranAddress']

      regional_office_response = service.routing.get_regional_office_by_zip_code(
        vet_info['postalCode'], vet_info['country'], vet_info['state'], 'VRE', parsed_form['veteranInformation']['ssn']
      )

      [
        regional_office_response[:regional_office][:number],
        regional_office_response[:regional_office][:name]
      ]
    rescue => e
      Rails.logger.warn(e.message)
      ['000', 'Not Found']
    end

    def bgs_client
      @service ||= BGS::Services.new(
        external_uid: parsed_form['email'],
        external_key:
      )
    end

    def external_key
      parsed_form.dig('veteranInformation', 'fullName', 'first') || parsed_form['email']
    end

    def veteran_va_file_number(user)
      response = ::BGS::People::Request.new.find_person_by_participant_id(user:)
      response.file_number
    rescue
      Rails.logger.warn('VRE claim unable to add VA File Number.', { user_uuid: user&.uuid })
      nil
    end

    def log_to_statsd(service)
      start_time = Time.current
      yield
      elapsed_time = Time.current - start_time
      StatsD.measure("api.1900.#{service}.response_time", elapsed_time, tags: {})
    end
  end
end
