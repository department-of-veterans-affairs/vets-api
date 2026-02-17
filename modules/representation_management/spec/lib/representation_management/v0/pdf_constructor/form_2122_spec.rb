# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../support/pdf_matcher'
require_relative '../../../../support/pdf_fill_helper'

describe RepresentationManagement::V0::PdfConstructor::Form2122 do
  include PdfFillHelper

  let(:field_16a_name) { 'form1[0].#subform[0].Name_Of_Official_Representative[0]' }
  let(:accredited_organization) { create(:accredited_organization, name: 'Best VSO') }
  let(:representative) do
    create(:accredited_individual,
           first_name: 'John',
           middle_initial: 'M',
           last_name: 'Representative',
           address_line1: '123 Fake Representative St',
           city: 'Portland',
           state_code: 'OR',
           zip_code: '12345',
           phone: '5555555555',
           email: 'representative@example.com')
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
      organization_id: accredited_organization.id,
      representative_id: representative.id,
      record_consent: true,
      consent_limits: %w[DRUG_ABUSE HIV SICKLE_CELL],
      consent_address_change: true
    }
  end

  def field_value(path, field_name)
    pdf_forms = PdfForms.new(Settings.binaries.pdftk)
    fields = pdf_forms.get_fields(path)
    fields.find { |f| f.name == field_name }&.value
  end

  it 'constructs the pdf with conditions present' do
    form = RepresentationManagement::Form2122Data.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      described_class.new(tempfile).construct(form)
      expected_pdf = Rails.root.join(
        'modules',
        'representation_management',
        'spec',
        'fixtures',
        '21-22',
        'v0',
        'default',
        '2122_with_limitations.pdf'
      )
      expect(tempfile.path).to match_pdf_content_of(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'matches the field values of a pdf with conditions present when unflattened' do
    form = RepresentationManagement::Form2122Data.new(data)
    Tempfile.create do |tempfile|
      tempfile.binmode
      described_class.new(tempfile).construct(form, flatten: false)
      expected_pdf = Rails.root.join(
        'modules',
        'representation_management',
        'spec',
        'fixtures',
        '21-22',
        'v0',
        'unflattened',
        '2122_with_limitations.pdf'
      )
      expect(tempfile.path).to match_pdf_fields(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'constructs the pdf with conditions present and no claimant' do
    data_no_claimant = data.reject { |key, _| key.to_s.include?('claimant') }
    form = RepresentationManagement::Form2122Data.new(data_no_claimant)
    Tempfile.create do |tempfile|
      tempfile.binmode
      described_class.new(tempfile).construct(form)
      expected_pdf = Rails.root.join(
        'modules',
        'representation_management',
        'spec',
        'fixtures',
        '21-22',
        'v0',
        'default',
        '2122_with_limitations_no_claimant.pdf'
      )
      expect(tempfile.path).to match_pdf_content_of(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'matches the field values of a pdf with no claimant with conditions present when unflattened' do
    data_no_claimant = data.reject { |key, _| key.to_s.include?('claimant') }
    form = RepresentationManagement::Form2122Data.new(data_no_claimant)

    Tempfile.create do |tempfile|
      tempfile.binmode
      described_class.new(tempfile).construct(form, flatten: false)
      expected_pdf = Rails.root.join(
        'modules',
        'representation_management',
        'spec',
        'fixtures',
        '21-22',
        'v0',
        'unflattened',
        '2122_with_limitations_no_claimant.pdf'
      )
      expect(tempfile.path).to match_pdf_fields(expected_pdf)
    end
    # The Tempfile is automatically deleted after the block ends
  end

  it 'does not populate Item 16A when no representative is provided (unflattened)' do
    data_no_rep = data.except(:representative_id)
    form = RepresentationManagement::Form2122Data.new(data_no_rep)

    Tempfile.create do |tempfile|
      tempfile.binmode
      described_class.new(tempfile).construct(form, flatten: false)

      value = field_value(tempfile.path, field_16a_name)
      expect(value).to be_blank
    end
  end

  it 'truncates Item 16A to MAX_16A_LEN when representative name is too long (unflattened)' do
    # Build a rep whose formatted name will definitely exceed the limit
    long_first = 'A' * 30
    long_last  = 'B' * 30

    long_rep = create(
      :accredited_individual,
      first_name: long_first,
      middle_initial: 'M',
      last_name: long_last,
      address_line1: '123 Fake Representative St',
      city: 'Portland',
      state_code: 'OR',
      zip_code: '12345',
      phone: '5555555555',
      email: 'representative@example.com'
    )

    form = RepresentationManagement::Form2122Data.new(data.merge(representative_id: long_rep.id))

    Tempfile.create do |tempfile|
      tempfile.binmode
      described_class.new(tempfile).construct(form, flatten: false)

      value = field_value(tempfile.path, field_16a_name)
      expected = "#{long_first} M #{long_last}".truncate(described_class::MAX_16A_LEN, omission: '')

      expect(value).to eq(expected)
    end
  end
end
