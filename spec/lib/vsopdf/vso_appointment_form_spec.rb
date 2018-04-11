# frozen_string_literal: true

require 'pdf_forms'
require 'rails_helper'
require 'vsopdf/vso_appointment_form'

describe VsoAppointmentForm do
  include SchemaMatchers

  form = VsoAppointmentForm.new(VsoAppointment.new(
                                  veteranFullName: 'Graham Test',
                                  insuranceNumber: '12345',
                                  vaFileNumber: '111223333',
                                  claimantEveningPhone: '555-1212',
                                  organizationName: 'some org',
                                  organizationRepresentativeName: 'John Smith',
                                  organizationRepresentativeTitle: 'Director of weird field names',
                                  disclosureExceptionHIV: true
  ))

  it 'should translate a VsoAppointment object' do
    # Spot check the arg translation
    args = form.to_pdf_args

    expect(args['F[0].Page_1[0].nameofvet[0]']).to eq 'Graham Test'
    expect(args['F[0].Page_1[0].insno[0]']).to eq '12345'
    expect(args['F[0].Page_1[0].eveningphonenumber[0]']).to eq '555-1212'
    expect(args['F[0].Page_1[0].nameofservice[0]']).to eq 'some org'
    expect(args['F[0].Page_1[0].jobtitile[0]']).to eq 'John Smith, Director of weird field names'
    expect(args['F[0].Page_1[0].infectionwiththehumanimmunodeficiencyvirushiv[0]']).to eq 1
  end

  it 'should generate a valid pdf' do
    path = form.generate_pdf

    # Read the pdf and get a hash of the filled fields
    fields = {}
    PdfForms.new(Settings.binaries.pdftk).get_fields(path).each { |f| fields[f.name] = f.value }

    expect(fields['F[0].Page_1[0].nameofvet[0]']).to eq 'Graham Test'
  end

  it 'should generate central mail metadata' do
    meta = form.get_metadata 'lib/vsopdf/VBA-21-22-ARE.pdf'
    expect(meta[:numberAttachments]).to eq 0
    expect(meta[:veteranFirstName]).to eq 'Graham'
    expect(meta[:veteranLastName]).to eq 'Test'
    expect(meta[:fileNumber]).to eq '111223333'
    expect(meta[:numberPages]).to eq 2
    expect(meta[:hashV]).to eq '817c57441e3696023e5adadc75a17a15d5ea0aa9e711b349210fb83d06323f3e'
    expect(meta[:uuid].length).to eq 36
    expect(meta[:receiveDt].match(/\A[\d]{4}-[\d]{2}-[\d]{2} [\d]{2}:[\d]{2}:[\d]{2}\Z/).nil?).to eq false
  end

  it 'should post a pdf to central mail' do
    VCR.use_cassette('vso_appointments/upload') do
      expect(form.send_pdf.status).to eq(200)
    end
  end
end
