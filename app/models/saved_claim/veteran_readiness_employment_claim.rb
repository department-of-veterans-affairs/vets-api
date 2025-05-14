# frozen_string_literal: true

require 'sentry_logging'
require 'res/ch31_form'

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  include SentryLogging

  FORM = '28-1900'
  FORMV2 = '28-1900_V2' # use full country name instead of abbreviation ("USA" -> "United States")
  # We will be adding numbers here and eventually completeley removing this and the caller to open up VRE submissions
  # to all vets
  PERMITTED_OFFICE_LOCATIONS = %w[].freeze

  REGIONAL_OFFICE_EMAILS = {
    '301' => 'VRC.VBABOS@va.gov',
    '304' => 'VRE.VBAPRO@va.gov',
    '306' => 'VRE.VBANYN@va.gov',
    '307' => 'VRC.VBABUF@va.gov',
    '308' => 'VRE.VBAHAR@va.gov',
    '309' => 'vre.vbanew@va.gov',
    '310' => 'VREBDD.VBAPHI@va.gov',
    '311' => 'VRE.VBAPIT@va.gov',
    '313' => 'VRE.VBABAL@va.gov',
    '314' => 'VRE.VBAROA@va.gov',
    '315' => 'VRE.VBAHUN@va.gov',
    '316' => 'VRETMP.VBAATG@va.gov',
    '317' => 'VRE281900.VBASPT@va.gov',
    '318' => 'VRC.VBAWIN@va.gov',
    '319' => 'VRC.VBACMS@va.gov',
    '320' => 'VREAPPS.VBANAS@va.gov',
    '321' => 'VRC.VBANOL@va.gov',
    '322' => 'VRE.VBAMGY@va.gov',
    '323' => 'VRE.VBAJAC@va.gov',
    '325' => 'VRE.VBACLE@va.gov',
    '326' => 'VRE.VBAIND@va.gov',
    '327' => 'VRE.VBALOU@va.gov',
    '328' => 'VAVBACHI.VRE@va.gov',
    '329' => 'VRE.VBADET@va.gov',
    '330' => 'VREApplications.VBAMIW@va.gov',
    '331' => 'VRC.VBASTL@va.gov',
    '333' => 'VRE.VBADES@va.gov',
    '334' => 'VRE.VBALIN@va.gov',
    '335' => 'VRC.VBASPL@va.gov',
    '339' => 'VRE.VBADEN@va.gov',
    '340' => 'VRC.VBAALB@va.gov',
    '341' => 'VRE.VBASLC@va.gov',
    '343' => 'VRC.VBAOAK@va.gov',
    '344' => 'ROVRC.VBALAN@va.gov',
    '345' => 'VRE.VBAPHO@va.gov',
    '346' => 'VRE.VBASEA@va.gov',
    '347' => 'VRE.VBABOI@va.gov',
    '348' => 'VRE.VBAPOR@va.gov',
    '349' => 'VREAPPS.VBAWAC@va.gov',
    '350' => 'VRE.VBALIT@va.gov',
    '351' => 'VREBDD.VBAMUS@va.gov',
    '354' => 'VRE.VBAREN@va.gov',
    '355' => 'MBVRE.VBASAJ@va.gov',
    '358' => 'VRE.VBAMPI@va.gov',
    '362' => 'VRE.VBAHOU@va.gov',
    '372' => 'VRE.VBAWAS@va.gov',
    '373' => 'VRE.VBAMAN@va.gov',
    '377' => 'EBENAPPS.VBASDC@va.gov',
    '402' => 'VRE.VBATOG@va.gov',
    '405' => 'VRE.VBAMAN@va.gov',
    '436' => 'VRC.VBAFHM@va.gov',
    '437' => 'VRC.VBAFAR@va.gov',
    '438' => 'VRC.VBAFAR@va.gov',
    '442' => 'VRE.VBADEN@va.gov',
    '452' => 'VRE.VBAWIC@va.gov',
    '459' => 'VRC.VBAHON@va.gov',
    '460' => 'VAVBA/WIM/RO/VR&E@vba.va.gov',
    '463' => 'VRE.VBAANC@va.gov',
    '000' => 'VRE.VBAPIT@va.gov'
  }.freeze

  def initialize(args)
    @sent_to_lighthouse = false
    super
  end

  def add_claimant_info(user)
    return if form.blank?

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

  def add_office_location(updated_form)
    regional_office = check_office_location
    @office_location = regional_office[0]
    office_name = regional_office[1]

    updated_form['veteranInformation']&.merge!({
                                                 'regionalOffice' => "#{@office_location} - #{office_name}",
                                                 'regionalOfficeName' => office_name,
                                                 'stationId' => @office_location
                                               })
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
      Rails.logger.warn('Participant id is blank when submitting VRE claim')
      send_to_lighthouse!(user)
    end

    email_addr = REGIONAL_OFFICE_EMAILS[@office_location] || 'VRE.VBACO@va.gov'
    Rails.logger.info('VRE claim sending email:', { email: email_addr, user_uuid: user.uuid })
    VeteranReadinessEmploymentMailer.build(user.participant_id, email_addr,
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

    uploader = ClaimsApi::VBMSUploader.new(
      filepath: Rails.root.join(form_path),
      file_number: parsed_form['veteranInformation']['VAFileNumber'] || parsed_form['veteranInformation']['ssn'],
      doc_type:
    )

    log_to_statsd('vbms') do
      response = uploader.upload!

      if response[:vbms_document_series_ref_id].present?
        updated_form = parsed_form
        updated_form['documentId'] = response[:vbms_document_series_ref_id]
        update!(form: updated_form.to_json)
      end
    end

    send_vbms_confirmation_email(user)
  rescue => e
    log_error(user, e)
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
        Rails.logger.warn('VRE: No SSN found for LOA3 user', { user_uuid: user.uuid })
      else
        Rails.logger.info('VRE: No SSN found for LOA1 user', { user_uuid: user.uuid })
      end
    end

    update!(form: form_copy.to_json)

    process_attachments!
    @sent_to_lighthouse = true

    send_lighthouse_confirmation_email(user)
  rescue => e
    Rails.logger.error('Error uploading VRE claim to Benefits Intake API', { user_uuid: user&.uuid, e: })
    raise
  end

  # Send claim via RES service
  # @param user [User] user account of submitting user
  # @return [Hash] Response payload of RES service
  def send_to_res(user)
    Rails.logger.info('VRE claim sending to RES service',
                      {
                        user_uuid: user.uuid,
                        was_sent: @sent_to_lighthouse,
                        user_present: user.present?
                      })

    service = RES::Ch31Form.new(user:, claim: self)
    service.submit
  end

  def add_errors_from_form_validation(form_errors)
    form_errors.each do |e|
      errors.add(e[:fragment], e[:message])
      e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
    end
    unless form_errors.empty?
      Rails.logger.error('SavedClaim form did not pass validation',
                         { form_id:, guid:, errors: form_errors })
    end
  end

  def form_matches_schema
    return unless form_is_string

    schema = VetsJsonSchema::SCHEMAS[self.class::FORM]
    schema_v2 = VetsJsonSchema::SCHEMAS[self.class::FORMV2]

    schema_errors = validate_schema(schema)
    validation_errors = validate_form(schema)

    if validation_errors.length.positive? && validation_errors.any? { |e| e[:fragment].end_with?('/country') }
      schema_v2_errors = validate_schema(schema_v2)
      v2_errors = validate_form(schema_v2)
      add_errors_from_form_validation(v2_errors)
      return schema_v2_errors.empty? && v2_errors.empty?
    end

    add_errors_from_form_validation(validation_errors)

    schema_errors.empty? && validation_errors.empty?
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  def send_vbms_confirmation_email(user)
    return if user.va_profile_email.blank?

    VANotify::EmailJob.perform_async(
      user.va_profile_email,
      Settings.vanotify.services.va_gov.template_id.ch31_vbms_form_confirmation_email,
      {
        'first_name' => user&.first_name&.upcase.presence,
        'date' => Time.zone.today.strftime('%B %d, %Y')
      }
    )
  end

  def send_lighthouse_confirmation_email(user)
    return if user.va_profile_email.blank?

    VANotify::EmailJob.perform_async(
      user.va_profile_email,
      Settings.vanotify.services.va_gov.template_id.ch31_central_mail_form_confirmation_email,
      {
        'first_name' => user&.first_name&.upcase.presence,
        'date' => Time.zone.today.strftime('%B %d, %Y')
      }
    )
  end

  def process_attachments!
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }

    Lighthouse::SubmitBenefitsIntakeClaim.new.perform(id)
  end

  def business_line
    'VRE'
  end

  # this failure email is not the ideal way to handle the Notification Emails as
  # part of the ZSF work, but with the initial timeline it handles the email as intended.
  # Future work will be integrating into the Va Notify common lib:
  # https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/veteran_facing_services/notification_email.rb
  def send_failure_email(email)
    if email.present?
      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.form1900_action_needed_email,
        {
          'first_name' => parsed_form.dig('veteranInformation', 'fullName', 'first'),
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => confirmation_number
        }
      )
    end
  end

  private

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

  def veteran_information
    errors.add(:form, 'Veteran Information is missing from form') if parsed_form['veteranInformation'].blank?
  end

  def veteran_va_file_number(user)
    response = BGS::People::Request.new.find_person_by_participant_id(user:)
    response.file_number
  rescue
    nil
  end

  def log_to_statsd(service)
    start_time = Time.current
    yield
    elapsed_time = Time.current - start_time
    StatsD.measure("api.1900.#{service}.response_time", elapsed_time, tags: {})
  end

  def log_error(user, e)
    if Flipper.enabled?(:vre_enable_vbms_exception_logging)
      Rails.logger.error('Error uploading VRE claim to VBMS.', { user_uuid: user.uuid, e: })
    else
      Rails.logger.error('Error uploading VRE claim to VBMS.', { user_uuid: user.uuid })
    end
  end
end
