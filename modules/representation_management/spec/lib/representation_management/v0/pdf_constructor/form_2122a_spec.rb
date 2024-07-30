# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../support/pdf_matcher'

describe RepresentationManagement::V0::PdfConstructor::Form2122a do
  let(:data) do
    {
      veteran_first_name: 'John',
      veteran_middle_initial: 'Q',
      veteran_last_name: 'Demo',
      veteran_social_security_number: '987654321',
      veteran_va_file_number: '123456789',
      veteran_date_of_birth: '12/31/1234',
      veteran_service_number: '987654321',
      veteran_service_branch: 'USPHS',
      veteran_address_line1: '123 Fake Veteran St',
      veteran_address_line2: '12345',
      veteran_city: 'Portland',
      veteran_state_code: 'OR',
      veteran_country: 'US',
      veteran_zip_code: '12345',
      veteran_zip_code_suffix: '6789',
      veteran_phone: '5555555555',
      veteran_email: 'veteran@example.com',
      claimant_first_name: 'John',
      claimant_middle_initial: 'Q',
      claimant_last_name: 'Claimant',
      claimant_date_of_birth: '12/31/1234',
      claimant_relationship: 'Spouse',
      claimant_address_line1: '123 Fake Claimant St',
      claimant_address_line2: '09876',
      claimant_city: 'Portland',
      claimant_state_code: 'OR',
      claimant_country: 'US',
      claimant_zip_code: '12345',
      claimant_zip_code_suffix: '6789',
      claimant_phone: '5555555555',
      claimant_email: 'claimant@example.com',
      representative_first_name: 'John',
      representative_middle_initial: 'Q',
      representative_last_name: 'Representative',
      representative_type: 'ATTORNEY',
      representative_address_line1: '123 Fake Representative St',
      representative_address_line2: 'Rep1',
      representative_city: 'Portland',
      representative_state_code: 'OR',
      representative_country: 'US',
      representative_zip_code: '12345',
      representative_zip_code_suffix: '6789',
      representative_phone: '2222222222',
      representative_email_address: 'representative@example.com',
      record_consent: true,
      consent_limits: [],
      consent_address_change: true,
      conditions_of_appointment: %w[a123 b456 c789]
    }
  end

  it 'constructs the pdf with conditions present' do
    form = RepresentationManagement::Form2122aData.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form)
      expected_pdf = Rails.root.join('modules',
                                     'representation_management',
                                     'spec',
                                     'fixtures',
                                     '21-22A',
                                     'v0',
                                     '2122a_conditions_and_limitations.pdf')
      expect(tempfile.path).to match_pdf_content_of(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'constructs the pdf with conditions present and no claimant' do
    data.delete_if { |key, _| key.to_s.include?('claimant') }
    form = RepresentationManagement::Form2122aData.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form)
      expected_pdf = Rails.root.join('modules',
                                     'representation_management',
                                     'spec',
                                     'fixtures',
                                     '21-22A',
                                     'v0',
                                     '2122a_conditions_and_limitations_no_claimant.pdf')
      expect(tempfile.path).to match_pdf_content_of(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end
end
