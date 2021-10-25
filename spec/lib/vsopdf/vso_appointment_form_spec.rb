# frozen_string_literal: true

require 'pdf_forms'
require 'rails_helper'
require 'vso_pdf/vso_appointment_form'

describe VSOAppointmentForm do
  include SchemaMatchers

  form = VSOAppointmentForm.new(VSOAppointment.new(
                                  veteran_full_name: {
                                    first: 'Graham',
                                    last: 'Test'
                                  },
                                  claimant_address: {
                                    street: '123 Fake St',
                                    street2: 'apt #1',
                                    city: 'Philadelphia',
                                    country: 'USA',
                                    state: 'PA',
                                    postal_code: '19119'
                                  },
                                  appointment_date: '2018-01-02',
                                  insurance_number: '12345',
                                  va_file_number: '111223333',
                                  claimant_evening_phone: '555-1212',
                                  organization_name: 'some org',
                                  organization_representative_name: 'John Smith',
                                  organization_representative_title: 'Director of weird field names',
                                  disclosure_exception_hiv: true
                                ))

  it 'translates a VSOAppointment object' do
    # Spot check the arg translation
    args = form.to_pdf_args

    expect(args['F[0].Page_1[0].nameofvet[0]']).to eq 'Graham Test'
    expect(args['F[0].Page_1[0].insno[0]']).to eq '12345'
    expect(args['F[0].Page_1[0].eveningphonenumber[0]']).to eq '555-1212'
    expect(args['F[0].Page_1[0].nameofservice[0]']).to eq 'some org'
    expect(args['F[0].Page_1[0].jobtitile[0]']).to eq 'John Smith, Director of weird field names'
    expect(args['F[0].Page_1[0].infectionwiththehumanimmunodeficiencyvirushiv[0]']).to eq 1
    expect(args['F[0].Page_1[0].address[0]']).to eq("123 Fake St\napt #1\nPhiladelphia, PA 19119\nUSA")
    expect(args['F[0].Page_1[0].Dateappt[0]']).to eq('2018-01-02')
  end

  it 'generates a valid pdf' do
    path = form.generate_pdf

    # Read the pdf and get a hash of the filled fields
    fields = PdfForms.new(Settings.binaries.pdftk).get_fields(path).map { |f| [f.name, f.value] }.to_h
    expect(fields['F[0].Page_1[0].nameofvet[0]']).to eq 'Graham Test'
  end

  it 'generates central mail metadata' do
    meta = form.get_metadata 'lib/vso_pdf/VBA-21-22-ARE.pdf'
    expect(meta[:numberAttachments]).to eq 0
    expect(meta[:veteranFirstName]).to eq 'Graham'
    expect(meta[:veteranLastName]).to eq 'Test'
    expect(meta[:fileNumber]).to eq '111223333'
    expect(meta[:numberPages]).to eq 2
    expect(meta[:hashV]).to eq '817c57441e3696023e5adadc75a17a15d5ea0aa9e711b349210fb83d06323f3e'
    expect(meta[:uuid].length).to eq 36
    expect(meta[:receiveDt].match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\Z/).nil?).to eq false
  end

  it 'posts a pdf to central mail' do
    VCR.use_cassette('vso_appointments/upload') do
      expect(form.send_pdf.status).to eq(200)
    end
  end
end
