# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../support/pdf_matcher'
require_relative '../../../../support/pdf_fill_helper'

describe RepresentationManagement::V0::PdfConstructor::Form2122a do
  include PdfFillHelper
  let(:representative) do
    create(:accredited_individual,
           first_name: 'John',
           middle_initial: 'M',
           last_name: 'Representative',
           address_line1: '123 Fake Representative St',
           city: 'Portland',
           state_code: 'OR',
           country_code_iso3: 'USA',
           zip_code: '12345',
           phone: '555-555-5555', # We're adding dashes here to make sure they aren't present in the pdf output.
           email: 'representative@example.com',
           individual_type: 'attorney')
  end
  let(:data) do
    {
      veteran_first_name: 'John',
      veteran_middle_initial: 'M',
      veteran_last_name: 'Veteran',
      veteran_social_security_number: '123456789',
      veteran_va_file_number: '123456789',
      veteran_date_of_birth: '1980-12-31',
      veteran_service_number: 'AA12345',
      veteran_service_branch: 'USPHS',
      veteran_address_line1: '123 Fake Veteran St',
      veteran_address_line2: '',
      veteran_city: 'Portland',
      veteran_state_code: 'OR',
      veteran_country: 'US',
      veteran_zip_code: '12345',
      veteran_zip_code_suffix: '6789',
      veteran_phone: '5555555555',
      veteran_email: 'veteran@example.com',
      claimant_first_name: 'John',
      claimant_middle_initial: 'M',
      claimant_last_name: 'Claimant',
      claimant_date_of_birth: '1980-12-31',
      claimant_relationship: 'Spouse',
      claimant_address_line1: '123 Fake Claimant St',
      claimant_address_line2: '',
      claimant_city: 'Portland',
      claimant_state_code: 'OR',
      claimant_country: 'US',
      claimant_zip_code: '12345',
      claimant_zip_code_suffix: '6789',
      claimant_phone: '5555555555',
      claimant_email: 'claimant@example.com',
      representative_id: representative.id,

      record_consent: true,
      consent_limits: %w[
        ALCOHOLISM
        DRUG_ABUSE
      ],
      consent_address_change: true,
      consent_inside_access: true,
      consent_outside_access: true,
      consent_team_members: [
        'Jane M Representative',
        'John M Representative',
        'Jane M Doe',
        'John M Doe',
        'Bobbie M Law',
        'Bob M Law',
        'Alice M Aster',
        'Arthur M Aster'
      ]

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
                                     'default',
                                     '2122a_conditions_and_limitations.pdf')
      expect(tempfile.path).to match_pdf_content_of(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'matches the field values of a pdf with conditions present when unflattened' do
    form = RepresentationManagement::Form2122aData.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form, flatten: false)
      expected_pdf = Rails.root.join('modules',
                                     'representation_management',
                                     'spec',
                                     'fixtures',
                                     '21-22A',
                                     'v0',
                                     'unflattened', # <- Important difference
                                     '2122a_conditions_and_limitations.pdf')
      expect(tempfile.path).to match_pdf_fields(expected_pdf)
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
                                     'default',
                                     '2122a_conditions_and_limitations_no_claimant.pdf')
      expect(tempfile.path).to match_pdf_content_of(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'matches the field values of a pdf with no claimant with conditions present when unflattened' do
    data.delete_if { |key, _| key.to_s.include?('claimant') }
    form = RepresentationManagement::Form2122aData.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form, flatten: false)
      expected_pdf = Rails.root.join('modules',
                                     'representation_management',
                                     'spec',
                                     'fixtures',
                                     '21-22A',
                                     'v0',
                                     'unflattened', # <- Important difference
                                     '2122a_conditions_and_limitations_no_claimant.pdf')
      expect(tempfile.path).to match_pdf_fields(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'constructs the pdf if the representative has no phone number' do
    representative.update!(phone: nil)
    form = RepresentationManagement::Form2122aData.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form)
      reader = PDF::Reader.new(tempfile.path)
      # Here we're just testing that the PDF is valid and has a version
      expect(reader.pdf_version).not_to be_nil
    end
    # The Tempfile is automatically deleted after the block ends
  end
end
