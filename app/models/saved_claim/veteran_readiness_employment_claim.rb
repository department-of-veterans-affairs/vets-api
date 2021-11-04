# frozen_string_literal: true

require 'sentry_logging'
require 'vre/ch31_form'

class SavedClaim::VeteranReadinessEmploymentClaim < SavedClaim
  include SentryLogging

  FORM = '28-1900'
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

  validate :veteran_information, on: :prepare_form_data

  def initialize(args)
    @sent_to_cmp = false
    super
  end

  def add_claimant_info(user)
    return if form.blank?

    updated_form = parsed_form

    add_veteran_info(updated_form, user) if user&.loa3?
    add_office_location(updated_form) if updated_form['veteranInformation'].present?

    update(form: updated_form.to_json)
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

    updated_form['veteranInformation']&.merge!({ 'regionalOffice' => "#{@office_location} - #{office_name}" })
  end

  def send_to_vre(user)
    prepare_form_data
    if user&.participant_id.blank?
      send_to_central_mail!
    else
      begin
        upload_to_vbms
      rescue
        send_to_central_mail!
      end
    end

    @office_location = check_office_location[0] if @office_location.nil?

    email_addr = REGIONAL_OFFICE_EMAILS[@office_location] || 'VRE.VBACO@va.gov'

    VeteranReadinessEmploymentMailer.build(user.participant_id, email_addr, @sent_to_cmp).deliver_later if user.present?

    # During Roll out our partners ask that we check vet location and if within proximity to specific offices,
    # send the data to them. We always send a pdf to VBMS
    return unless PERMITTED_OFFICE_LOCATIONS.include?(@office_location)

    service = VRE::Ch31Form.new(user: user, claim: self)
    service.submit
  end

  def upload_to_vbms(doc_type: '1167')
    form_path = PdfFill::Filler.fill_form(self)

    uploader = ClaimsApi::VBMSUploader.new(
      filepath: form_path,
      file_number: parsed_form['veteranInformation']['VAFileNumber'] || parsed_form['veteranInformation']['ssn'],
      doc_type: doc_type
    )

    log_to_statsd('vbms') do
      uploader.upload!
    end
  end

  def send_to_central_mail!
    form_copy = parsed_form

    form_copy['veteranSocialSecurityNumber'] = parsed_form.dig('veteranInformation', 'ssn')
    form_copy['veteranFullName'] = parsed_form.dig('veteranInformation', 'fullName')
    form_copy['vaFileNumber'] = parsed_form.dig('veteranInformation', 'VAFileNumber')

    update(form: form_copy.to_json)

    log_message_to_sentry(guid, :warn, { attachment_id: guid }, { team: 'vfs-ebenefits' })
    @sent_to_cmp = true
    log_to_statsd('cmp') do
      process_attachments!
    end
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
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
    log_message_to_sentry(e.message, :warn, {}, { team: 'vfs-ebenefits' })
    ['000', 'Not Found']
  end

  def bgs_client
    @service ||= BGS::Services.new(
      external_uid: parsed_form['email'],
      external_key: external_key
    )
  end

  def external_key
    parsed_form.dig('veteranInformation', 'fullName', 'first') || parsed_form['email']
  end

  def prepare_form_data
    form_copy = parsed_form
    appointment_time_preferences = form_copy['appointmentTimePreferences'].map do |key_value|
      key_value[0].downcase if key_value[1] == true
    end.compact

    # VRE now needs an array of times
    form_copy['appointmentTimePreferences'] = appointment_time_preferences

    update(form: form_copy.to_json)
  end

  def veteran_information
    return errors.add(:form, 'Veteran Information is missing from form') if parsed_form['veteranInformation'].blank?
  end

  def veteran_va_file_number(user)
    service = BGS::PeopleService.new(user)
    StatsD.measure('api.1900.bgs.response_time') do
      @response = service.find_person_by_participant_id
    end
    file_number = @response[:file_nbr]
    file_number.presence
  rescue
    nil
  end

  def log_to_statsd(service)
    start_time = Time.current
    yield
    elapsed_time = Time.current - start_time
    StatsD.measure("api.1900.#{service}.response_time", elapsed_time, tags: {})
  end
end
