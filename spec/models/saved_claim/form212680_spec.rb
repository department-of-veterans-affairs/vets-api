# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form212680, type: :model do
  let(:valid_form_data) do
    {
      veteranInformation: {
        fullName: { first: 'John', middle: 'A', last: 'Doe' },
        ssn: '123456789',
        vaFileNumber: '987654321',
        dateOfBirth: '1950-01-01'
      },
      claimantInformation: {
        fullName: { first: 'Jane', middle: 'B', last: 'Doe' },
        relationship: 'Spouse',
        address: {
          street: '123 Main St',
          city: 'Springfield',
          state: 'IL',
          postalCode: '62701'
        }
      },
      benefitInformation: {
        claimType: 'Aid and Attendance'
      },
      additionalInformation: {
        currentlyHospitalized: false,
        nursingHome: false
      },
      veteranSignature: {
        signature: 'John A Doe',
        date: Time.zone.today.to_s
      }
    }.to_json
  end

  describe 'constants' do
    it 'has the correct form id' do
      expect(described_class::FORM).to eq('21-2680')
    end
  end

  describe '#regional_office' do
    subject { described_class.new(form: valid_form_data) }

    it 'returns the Pension Management Center address' do
      expect(subject.regional_office).to eq([
                                              'Department of Veterans Affairs',
                                              'Pension Management Center',
                                              'P.O. Box 5365',
                                              'Janesville, WI 53547-5365'
                                            ])
    end
  end

  describe '#business_line' do
    subject { described_class.new(form: valid_form_data) }

    it 'returns PMC' do
      expect(subject.business_line).to eq('PMC')
    end
  end

  describe '#document_type' do
    subject { described_class.new(form: valid_form_data) }

    it 'returns 540 for Aid and Attendance/Housebound' do
      expect(subject.document_type).to eq(540)
    end
  end

  describe '#veteran_sections' do
    subject { described_class.new(form: valid_form_data) }

    it 'extracts only veteran sections I-V' do
      sections = subject.veteran_sections

      expect(sections.keys).to match_array(%w[
                                             veteranInformation
                                             claimantInformation
                                             benefitInformation
                                             additionalInformation
                                             veteranSignature
                                           ])
    end

    it 'includes all veteran information' do
      sections = subject.veteran_sections
      veteran_info = sections['veteranInformation']

      expect(veteran_info['fullName']['first']).to eq('John')
      expect(veteran_info['ssn']).to eq('123456789')
      expect(veteran_info['vaFileNumber']).to eq('987654321')
    end
  end

  describe '#veteran_sections_complete?' do
    context 'with complete veteran sections' do
      subject { described_class.new(form: valid_form_data) }

      it 'returns true' do
        expect(subject.veteran_sections_complete?).to be true
      end
    end

    context 'with incomplete veteran sections' do
      subject { described_class.new(form: incomplete_form_data) }

      let(:incomplete_form_data) do
        {
          veteranInformation: {
            fullName: { first: 'John' }
            # Missing required fields
          }
        }.to_json
      end

      it 'returns false' do
        expect(subject.veteran_sections_complete?).to be false
      end
    end
  end

  describe '#attachment_keys' do
    subject { described_class.new(form: valid_form_data) }

    it 'returns an empty frozen array' do
      keys = subject.attachment_keys
      expect(keys).to eq([])
      expect(keys).to be_frozen
    end
  end

  describe 'validations' do
    context 'with valid form data' do
      subject { described_class.new(form: valid_form_data) }

      it 'is valid' do
        expect(subject.valid?).to be true
      end
    end

    context 'with missing veteran first name' do
      subject { described_class.new(form: invalid_form_data) }

      let(:invalid_form_data) do
        data = JSON.parse(valid_form_data)
        data['veteranInformation']['fullName']['first'] = nil
        data.to_json
      end

      it 'is invalid' do
        expect(subject.valid?).to be false
        expect(subject.errors[:form]).to include('Veteran first name is required')
      end
    end

    context 'with invalid SSN format' do
      subject { described_class.new(form: invalid_form_data) }

      let(:invalid_form_data) do
        data = JSON.parse(valid_form_data)
        data['veteranInformation']['ssn'] = '12345'
        data.to_json
      end

      it 'is invalid' do
        expect(subject.valid?).to be false
        expect(subject.errors[:form]).to include('Invalid Social Security Number format')
      end
    end

    context 'with signature older than 60 days' do
      subject { described_class.new(form: invalid_form_data) }

      let(:invalid_form_data) do
        data = JSON.parse(valid_form_data)
        data['veteranSignature']['date'] = 61.days.ago.to_date.to_s
        data.to_json
      end

      it 'is invalid' do
        expect(subject.valid?).to be false
        expect(subject.errors[:form]).to include('Signature date must be within the last 60 days')
      end
    end
  end
end
