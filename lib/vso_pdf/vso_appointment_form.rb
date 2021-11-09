# frozen_string_literal: true

require 'pdf_forms'
require 'tempfile'
require 'securerandom'

class VSOAppointmentForm
  include Common::Client::Concerns::Monitoring
  STATSD_KEY_PREFIX = 'api.vso_appoinment_form'

  def initialize(appt)
    @appt = appt
  end

  def address_to_s(addr)
    street = addr.street2.nil? ? addr.street : "#{addr.street}\n#{addr.street2}"
    "#{street}\n#{addr.city}, #{addr.state} #{addr.postal_code}\n#{addr.country}"
  end

  def name_to_s(name)
    return '' if name.nil?

    n = name.first
    n += " #{name.middle}" unless name.middle.nil?
    n += " #{name.last}"
    n += ", #{name.suffix}" unless name.suffix.nil?
    n
  end

  def to_pdf_args
    {
      nameofvet: name_to_s(@appt.veteran_full_name),
      SSNno: @appt.veteran_ssn,
      filenumber: @appt.va_file_number,
      insno: @appt.insurance_number,
      claimantname: name_to_s(@appt.claimant_full_name),
      address: address_to_s(@appt.claimant_address),
      emailaddress: @appt.claimant_email,
      daytime: @appt.claimant_daytime_phone,
      eveningphonenumber: @appt.claimant_evening_phone,
      relationship: @appt.relationship,
      Dateappt: @appt.appointment_date,
      nameofservice: @appt.organization_name,
      'e-mailaddressoftheorganizationnamedinitem3a': @appt.organization_email,
      jobtitile: "#{@appt.organization_representative_name}, #{@appt.organization_representative_title}",
      drugabuse: @appt.disclosure_exception_drug_abuse ? 1 : 0,
      alcoholismoralcohoabuse: @appt.disclosure_exception_alcoholism ? 1 : 0,
      infectionwiththehumanimmunodeficiencyvirushiv: @appt.disclosure_exception_hiv ? 1 : 0,
      sicklecellanemia: @appt.disclosure_exception_sickle_cell_anemia ? 1 : 0
    }.transform_keys { |k| "F[0].Page_1[0].#{k}[0]" }
  end

  def generate_pdf
    tmpf = Tempfile.new(['vsopdf', '.pdf'])
    args = to_pdf_args.merge('F[0].Page_1[0].authorize[0]': 1, 'F[0].Page_1[0].authorize[1]': 1)
    PdfForms.new(Settings.binaries.pdftk).fill_form 'lib/vso_pdf/VBA-21-22-ARE.pdf', tmpf.path, args
    tmpf.close
    tmpf.path
  end

  def get_metadata(path)
    {
      numberAttachments: 0,
      veteranFirstName: @appt.veteran_full_name.first,
      veteranLastName: @appt.veteran_full_name.last,
      source: 'Vets.gov',
      uuid: SecureRandom.uuid,
      zipCode: @appt.claimant_address.postal_code,
      receiveDt: Time.zone.now.strftime('%Y-%m-%d %H:%M:%S'),
      fileNumber: @appt.va_file_number,
      hashV: Digest::SHA256.file(path).hexdigest,
      docType: 'burial',
      numberPages: 2
    }
  end

  def send_pdf
    path = generate_pdf

    conn = Faraday.new("https://#{Settings.central_mail.upload.host}") do |fd|
      fd.request :multipart
      fd.request :url_encoded
      fd.adapter Faraday.default_adapter
    end

    body = {
      token: Settings.central_mail.upload.token,
      document: Faraday::UploadIO.new(path, Mime[:pdf].to_s),
      metadata: get_metadata(path).to_json
    }

    with_monitoring { conn.post '/VADocument/upload', body }
  end
end
