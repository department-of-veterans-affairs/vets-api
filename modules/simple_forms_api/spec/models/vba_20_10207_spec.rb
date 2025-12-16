# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.shared_examples 'point_of_contact_email' do
  context 'should use point of contact email' do
    let(:email) { 'pointy@contact.com' }

    before do
      data.merge!(
        {
          'living_situation' => { 'NONE' => true },
          'point_of_contact_email' => email
        }
      )
    end

    it 'returns the point of contact email' do
      expect(described_class.new(data).notification_email_address).to eq email
    end
  end
end

RSpec.describe SimpleFormsApi::VBA2010207 do
  it_behaves_like 'zip_code_is_us_based', %w[veteran_mailing_address non_veteran_mailing_address]

  describe 'requester_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: statement_of_truth_signature },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: statement_of_truth_signature },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'power-of-attorney', expected: nil }
    ].each do |data|
      preparer_type = data[:preparer_type]
      third_party_type = data[:third_party_type]
      expected = data[:expected]

      it 'returns the right string' do
        form = SimpleFormsApi::VBA2010207.new(
          {
            'preparer_type' => preparer_type,
            'third_party_type' => third_party_type,
            'statement_of_truth_signature' => statement_of_truth_signature
          }
        )

        expect(form.requester_signature).to eq(expected)
      end
    end
  end

  describe 'third_party_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative',
        expected: statement_of_truth_signature },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative',
        expected: statement_of_truth_signature },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'power-of-attorney',
        expected: statement_of_truth_signature }
    ].each do |data|
      preparer_type = data[:preparer_type]
      third_party_type = data[:third_party_type]
      expected = data[:expected]

      it 'returns the right string' do
        form = SimpleFormsApi::VBA2010207.new(
          {
            'preparer_type' => preparer_type,
            'third_party_type' => third_party_type,
            'statement_of_truth_signature' => statement_of_truth_signature
          }
        )

        expect(form.third_party_signature).to eq(expected)
      end
    end
  end

  describe 'power_of_attorney_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'power-of-attorney',
        expected: statement_of_truth_signature }
    ].each do |data|
      preparer_type = data[:preparer_type]
      third_party_type = data[:third_party_type]
      expected = data[:expected]

      it 'returns the right string' do
        form = SimpleFormsApi::VBA2010207.new(
          {
            'preparer_type' => preparer_type,
            'third_party_type' => third_party_type,
            'statement_of_truth_signature' => statement_of_truth_signature
          }
        )

        expect(form.power_of_attorney_signature).to eq(expected)
      end
    end
  end

  describe '#notification_first_name' do
    context 'preparer is veteran' do
      let(:data) do
        {
          'preparer_type' => 'veteran',
          'veteran_full_name' => {
            'first' => 'Veteran',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the veteran first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Veteran'
      end
    end

    context 'preparer is non-veteran' do
      let(:data) do
        {
          'preparer_type' => 'non-veteran',
          'non_veteran_full_name' => {
            'first' => 'Non-Veteran',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the non-veteran first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Non-Veteran'
      end
    end

    context 'preparer is third party' do
      let(:data) do
        {
          'preparer_type' => 'third-party',
          'third_party_full_name' => {
            'first' => 'Third Party',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the third party first name' do
        expect(described_class.new(data).notification_first_name).to eq 'Third Party'
      end
    end
  end

  describe '#notification_last_name' do
    context 'preparer is veteran' do
      let(:data) do
        {
          'preparer_type' => 'veteran',
          'veteran_full_name' => {
            'first' => 'Veteran',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the veteran last name' do
        expect(described_class.new(data).notification_last_name).to eq 'Eteranvay'
      end
    end

    context 'preparer is non-veteran' do
      let(:data) do
        {
          'preparer_type' => 'non-veteran',
          'non_veteran_full_name' => {
            'first' => 'Non-Veteran',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the non-veteran last name' do
        expect(described_class.new(data).notification_last_name).to eq 'Eteranvay'
      end
    end

    context 'preparer is third party' do
      let(:data) do
        {
          'preparer_type' => 'third-party',
          'third_party_full_name' => {
            'first' => 'Third Party',
            'last' => 'Eteranvay'
          }
        }
      end

      it 'returns the third party last name' do
        expect(described_class.new(data).notification_last_name).to eq 'Eteranvay'
      end
    end
  end

  describe '#notification_email_address' do
    context 'preparer is veteran' do
      let(:data) do
        {
          'preparer_type' => 'veteran',
          'veteran_email_address' => 'a@b.com'
        }
      end

      it 'returns the veteran email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end

      it_behaves_like 'point_of_contact_email'
    end

    context 'preparer is non-veteran' do
      let(:data) do
        {
          'preparer_type' => 'non-veteran',
          'non_veteran_email_address' => 'a@b.com'
        }
      end

      it 'returns the non-veteran email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end

      it_behaves_like 'point_of_contact_email'
    end

    context 'preparer is third party' do
      let(:data) do
        {
          'preparer_type' => 'third-party',
          'third_party_email_address' => 'a@b.com'
        }
      end

      it 'returns the third party email address' do
        expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
      end
    end
  end

  describe '#notification_point_of_contact_name' do
    let(:name) { 'Pointy Contact' }
    let(:data) do
      { 'point_of_contact_name' => name }
    end

    it 'returns the point of contact name' do
      expect(described_class.new(data).notification_point_of_contact_name).to eq name
    end
  end

  describe '#should_send_to_point_of_contact?' do
    let(:data) { {} }

    context 'preparer is not third party' do
      %w[veteran non-veteran].each do |preparer_type|
        before { data['preparer_type'] = preparer_type }

        context 'living situation is NONE' do
          before { data['living_situation'] = { 'NONE' => true } }

          it 'returns true' do
            expect(described_class.new(data).should_send_to_point_of_contact?).to be true
          end
        end

        context 'living situation is not NONE' do
          before { data['living_situation'] = { 'NONE' => false } }

          it 'returns false' do
            expect(described_class.new(data).should_send_to_point_of_contact?).to be false
          end
        end
      end
    end

    context 'preparer is third party' do
      %w[third-party-non-veteran third-party-veteran].each do |preparer_type|
        before { data['preparer_type'] = preparer_type }

        context 'living situation is NONE' do
          before { data['living_situation'] = { 'NONE' => true } }

          it 'returns false' do
            expect(described_class.new(data).should_send_to_point_of_contact?).to be false
          end
        end

        context 'living situation is not NONE' do
          before { data['living_situation'] = { 'NONE' => false } }

          it 'returns false' do
            expect(described_class.new(data).should_send_to_point_of_contact?).to be false
          end
        end
      end
    end
  end

  describe '#add_vsi_flash' do
    let(:data) { {} }
    let(:form) { described_class.new(data) }
    let(:vsi_service) { instance_double(SimpleFormsApi::VsiFlashService) }

    before do
      allow(SimpleFormsApi::VsiFlashService).to receive(:new).and_return(vsi_service)
    end

    it 'returns early when VSI_SI is falsey' do
      expect(SimpleFormsApi::VsiFlashService).not_to receive(:new)
      form.add_vsi_flash
    end

    it 'calls service when VSI_SI is true' do
      data['other_reasons'] = { 'VSI_SI' => true }
      expect(vsi_service).to receive(:add_flash_to_bgs)
      form.add_vsi_flash
    end
  end

  describe '#facility_name' do
    let(:data) do
      {
        'medical_treatments' => [
          {
            'facility_name' => 'Test Hospital',
            'facility_address' => {
              'street' => '123 Main St',
              'city' => 'Test City',
              'state' => 'TS',
              'postal_code' => '12345',
              'country' => 'USA'
            }
          }
        ]
      }
    end

    it 'returns formatted facility name and address' do
      result = described_class.new(data).facility_name(1)
      expect(result).to include('Test Hospital')
      expect(result).to include('123 Main St')
    end

    it 'returns nil when facility does not exist' do
      expect(described_class.new(data).facility_name(2)).to be_nil
    end
  end

  describe '#facility_address' do
    let(:data) do
      {
        'medical_treatments' => [
          {
            'facility_address' => {
              'street' => '123 Main St',
              'city' => 'Test City',
              'state' => 'TS',
              'postal_code' => '12345',
              'country' => 'USA'
            }
          }
        ]
      }
    end

    it 'returns formatted address' do
      result = described_class.new(data).facility_address(1)
      expect(result).to include('123 Main St')
      expect(result).to include('Test City, TS')
      expect(result).to include('12345')
      expect(result).to include('USA')
    end
  end

  describe '#facility_month' do
    let(:data) do
      {
        'medical_treatments' => [
          { 'start_date' => '2023-05-15' }
        ]
      }
    end

    it 'returns the month from start_date' do
      expect(described_class.new(data).facility_month(1)).to eq('05')
    end
  end

  describe '#facility_day' do
    let(:data) do
      {
        'medical_treatments' => [
          { 'start_date' => '2023-05-15' }
        ]
      }
    end

    it 'returns the day from start_date' do
      expect(described_class.new(data).facility_day(1)).to eq('15')
    end
  end

  describe '#facility_year' do
    let(:data) do
      {
        'medical_treatments' => [
          { 'start_date' => '2023-05-15' }
        ]
      }
    end

    it 'returns the year from start_date' do
      expect(described_class.new(data).facility_year(1)).to eq('2023')
    end
  end

  describe '#words_to_remove' do
    let(:data) do
      {
        'veteran_id' => { 'ssn' => '123456789' },
        'veteran_date_of_birth' => '1990-01-01',
        'veteran_mailing_address' => { 'postal_code' => '12345-6789' },
        'veteran_phone' => '555-123-4567',
        'non_veteran_date_of_birth' => '1990-02-02',
        'non_veteran_ssn' => { 'ssn' => '987654321' },
        'non_veteran_phone' => '555-987-6543'
      }
    end

    it 'returns array of words to remove' do
      result = described_class.new(data).words_to_remove
      expect(result).to be_an(Array)
      expect(result).to include('123', '45', '6789')
    end
  end

  describe '#metadata' do
    let(:data) do
      {
        'veteran_full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'veteran_id' => { 'ssn' => '123456789' },
        'veteran_mailing_address' => { 'postal_code' => '12345' },
        'form_number' => '20-10207'
      }
    end

    it 'returns metadata hash' do
      result = described_class.new(data).metadata
      expect(result['veteranFirstName']).to eq('John')
      expect(result['veteranLastName']).to eq('Doe')
      expect(result['fileNumber']).to eq('123456789')
      expect(result['zipCode']).to eq('12345')
      expect(result['source']).to eq('VA Platform Digital Forms')
      expect(result['docType']).to eq('20-10207')
      expect(result['businessLine']).to eq('CMP')
    end
  end

  describe '#desired_stamps' do
    let(:data) do
      {
        'preparer_type' => 'veteran',
        'statement_of_truth_signature' => 'John Doe'
      }
    end

    it 'returns stamps array for veteran preparer' do
      result = described_class.new(data).desired_stamps
      expect(result).to be_an(Array)
      expect(result.first[:text]).to eq('John Doe')
      expect(result.first[:page]).to eq(4)
    end

    it 'returns different coords for power of attorney' do
      data['preparer_type'] = 'third-party-veteran'
      data['third_party_type'] = 'power-of-attorney'
      result = described_class.new(data).desired_stamps
      expect(result.first[:coords]).to eq([[50, 440]])
    end
  end

  describe '#submission_date_stamps' do
    let(:data) { {} }
    let(:timestamp) { Time.zone.parse('2023-05-15 10:30:00 UTC') }

    it 'returns submission date stamps' do
      result = described_class.new(data).submission_date_stamps(timestamp)
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first[:text]).to eq('Application Submitted:')
      expect(result.last[:text]).to include('UTC')
    end
  end

  describe '#track_user_identity' do
    let(:data) do
      {
        'preparer_type' => 'veteran',
        'third_party_type' => 'representative',
        'living_situation' => { 'HOMELESS' => true, 'NONE' => false },
        'other_reasons' => { 'ALS' => true, 'VSI_SI' => false }
      }
    end

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    it 'tracks user identity and logs information' do
      described_class.new(data).track_user_identity('ABC123')

      expect(StatsD).to have_received(:increment).with('api.simple_forms_api.20_10207.veteran representative')
      expect(Rails.logger).to have_received(:info).with(
        'Simple forms api - 20-10207 submission user identity',
        identity: 'veteran representative',
        confirmation_number: 'ABC123'
      )
      expect(Rails.logger).to have_received(:info).with(
        'Simple forms api - 20-10207 submission living situations and other reasons for request',
        living_situations: 'HOMELESS',
        other_reasons: 'ALS'
      )
    end
  end
end
