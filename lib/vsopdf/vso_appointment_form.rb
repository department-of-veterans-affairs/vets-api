# frozen_string_literal: true

require 'pdf_forms'
require 'tempfile'
require 'securerandom'

class VsoAppointmentForm
  def initialize(appt)
    @appt = appt
  end

  def to_pdf_args
    {
      "nameofvet": @appt.veteranFullName,
      "SSNno": @appt.veteranSSN,
      "filenumber": @appt.vaFileNumber,
      "insno": @appt.insuranceNumber,
      "claimantname": @appt.claimantFullName,
      "address": @appt.claimantAddress,
      "emailaddress": @appt.claimantEmail,
      "daytime": @appt.claimantDaytimePhone,
      "eveningphonenumber": @appt.claimantEveningPhone,
      "relationship": @appt.relationship,
      "Date@appt": @appt.appointmentDate,
      "nameofservice": @appt.organizationName,
      "e-mailaddressoftheorganizationnamedinitem3a": @appt.organizationEmail,
      "jobtitile": "#{@appt.organizationRepresentativeName}, #{@appt.organizationRepresentativeTitle}",
      "drugabuse": @appt.disclosureExceptionDrugAbuse ? 1 : 0,
      "alcoholismoralcoholabuse": @appt.disclosureExceptionAlcoholism ? 1 : 0,
      "infectionwiththehumanimmunodeficiencyvirushiv": @appt.disclosureExceptionHIV ? 1 : 0,
      "sicklecellanemia": @appt.disclosureExceptionSickleCellAnemia ? 1 : 0
    }.map { |k, v| ["F[0].Page_1[0].#{k}[0]", v] }.to_h
  end

  def generate_pdf
    tmpf = Tempfile.new(['vsopdf', '.pdf'])
    PdfForms.new(Settings.binaries.pdftk).fill_form 'lib/vsopdf/VBA-21-22-ARE.pdf', tmpf.path, to_pdf_args
    tmpf.close
    tmpf.path
  end

  def get_metadata(path)
    {
      "numberAttachments": 0,
      "veteranFirstName": @appt.veteranFullName.split(' ').shift,
      "veteranLastName": @appt.veteranFullName.split(' ').pop,
      "source": 'Vets.gov',
      "uuid": SecureRandom.uuid,
      "zipCode": '10001', # TODO: get the actual zip code
      "receiveDt": Time.zone.now.strftime('%Y-%m-%d %H:%M:%S'),
      "fileNumber": @appt.vaFileNumber,
      "hashV": Digest::SHA256.file(path).hexdigest,
      "docType": 'burial',
      "numberPages": 2
    }
  end

  def send_pdf
    path = generate_pdf
    conn = Faraday.new("https://#{Settings.pension_burial.upload.host}") do |fd|
      fd.request :multipart
      fd.request :url_encoded
      fd.adapter Faraday.default_adapter
    end

    body = {
      "token": Settings.pension_burial.upload.token,
      "document": Faraday::UploadIO.new(path, Mime[:pdf].to_s),
      "metadata": get_metadata(path).to_json
    }

    conn.post '/VADocument/upload', body
  end
end
