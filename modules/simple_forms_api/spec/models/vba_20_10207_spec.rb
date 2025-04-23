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
end
