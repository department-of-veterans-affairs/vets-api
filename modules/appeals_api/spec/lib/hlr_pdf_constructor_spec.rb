# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/hlr_pdf_constructor'

describe AppealsApi::HlrPdfConstructor do
  it 'should generate the PDF' do
    target_veteran = OpenStruct.new(
      first_name: 'Bob',
      middle_name: 'Billy',
      last_name: 'Smith',
      ssn:  '123456789',
      birth_date: Date.today,
      claimant_first_name: 'Bobby',
      claimant_middle_name: 'Bojangles',
      claimant_last_name: 'Jones',
      address_1: '123 Not Real St.',
      address_2: 'appt 1337',
      city: 'Eau Claire',
      state: 'WI',
      country: 'USA',
      zip: '54703',
      zip_last_4: '1234',
      benefit_type: 'compensation',
      same_office: true,
      informal_conference: true,
      conference_time: '10am-12:30pm',
      rep_contact_info: 'Steve Jobs - 555-555-5555',
      issues: [
        { specific_issue: 'I dont really know what will be in here', decision_date: 1.year.ago},
        { specific_issue: 'I dont really know what will be in here either', decision_date: 2.year.ago}
      ]

    )
    pdf = AppealsApi::HlrPdfConstructor.new(target_veteran)
    pdf.fill_pdf
  end

end
