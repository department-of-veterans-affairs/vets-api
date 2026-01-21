# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/person_option'

describe VAProfile::Models::PersonOption, type: :model do
  let(:person_option) do
    described_class.new(
      id: 123,
      item_id: 4,
      option_id: 30,
      effective_start_date: '2025-11-25T00:00:00Z',
      source_date: '2025-11-25T00:00:00Z',
      source_system_user: 'test-user',
      originating_source_system: 'TEST_SYSTEM'
    )
  end

  let(:api_response_body) do
    {
      'txAuditId' => 'fake-tx-audit-id-123',
      'status' => 'COMPLETED_SUCCESS',
      'bios' => [
        {
          'person_option_id' => 123,
          'item_id' => 4,
          'option_id' => 30,
          'effective_start_date' => '2025-11-25T00:00:00Z',
          'source_date' => '2025-11-25T00:00:00Z',
          'source_system_user' => 'test-user',
          'originating_source_system' => 'TEST_SYSTEM',
          'option_label' => 'Does Not Prefer Assistance',
          'option_type_code' => 'STRING',
          'option_value_string' => 'NO_ASSISTANCE'
        },
        {
          'person_option_id' => 456,
          'item_id' => 3,
          'option_id' => 18,
          'effective_start_date' => '2025-11-25T00:00:00Z',
          'source_date' => '2025-11-25T00:00:00Z',
          'source_system_user' => 'test-user',
          'originating_source_system' => 'TEST_SYSTEM',
          'option_label' => 'Monday Morning',
          'option_type_code' => 'STRING',
          'option_value_string' => 'MONDAY_MORNING'
        }
      ]
    }
  end

  describe 'validations' do
    describe 'item_id validation' do
      it 'is invalid without item_id' do
        option = described_class.new(option_id: 5)
        expect(option).not_to be_valid
        expect(option.errors[:item_id]).to include("can't be blank")
      end

      it 'is invalid with non-positive item_id' do
        option = described_class.new(item_id: 0, option_id: 5)
        expect(option).not_to be_valid
        expect(option.errors[:item_id]).to include('must be greater than 0')
      end
    end

    describe 'option_id validation' do
      it 'is invalid without option_id' do
        option = described_class.new(item_id: 1)
        expect(option).not_to be_valid
        expect(option.errors[:option_id]).to include("can't be blank")
      end

      it 'is invalid with non-positive option_id' do
        option = described_class.new(item_id: 1, option_id: -1)
        expect(option).not_to be_valid
        expect(option.errors[:option_id]).to include('must be greater than 0')
      end
    end

    it 'is valid with positive item_id and option_id' do
      option = described_class.new(item_id: 1, option_id: 5)
      expect(option).to be_valid
    end
  end

  describe '#mark_for_deletion' do
    it 'sets effective_end_date to current time' do
      freeze_time = Time.parse('2025-12-02T12:00:00Z')
      allow(Time).to receive(:now).and_return(freeze_time)

      result = person_option.mark_for_deletion

      expect(result.effective_end_date).to eq(freeze_time)
      expect(result).to eq(person_option)
    end
  end

  describe '.from_frontend_selection' do
    let(:item_id) { 1 }
    let(:option_ids) { [5, 7] }

    it 'creates PersonOption instances from frontend selection' do
      options = described_class.from_frontend_selection(item_id, option_ids)

      expect(options.length).to eq(2)
      expect(options).to all(be_a(described_class))
    end

    it 'sets correct attributes for each option' do
      options = described_class.from_frontend_selection(item_id, option_ids)

      options.each_with_index do |option, index|
        expect(option.item_id).to eq(item_id)
        expect(option.option_id).to eq(option_ids[index])
      end
    end

    it 'handles single option_id' do
      options = described_class.from_frontend_selection(item_id, 5)

      expect(options.length).to eq(1)
      expect(options.first.option_id).to eq(5)
    end

    it 'handles nil option_ids' do
      options = described_class.from_frontend_selection(item_id, nil)

      expect(options).to eq([])
    end
  end

  describe '.to_frontend_format' do
    let(:person_options) do
      [
        described_class.new(item_id: 1, option_id: 5),
        described_class.new(item_id: 1, option_id: 7),
        described_class.new(item_id: 2, option_id: 10),
        described_class.new(item_id: 2, option_id: 14)
      ]
    end

    it 'groups options by item_id' do
      result = described_class.to_frontend_format(person_options)

      expect(result.length).to eq(2)
      expect(result).to include(
        { item_id: 1, option_ids: [5, 7] },
        { item_id: 2, option_ids: [10, 14] }
      )
    end

    it 'sorts option_ids within each group' do
      unsorted_options = [
        described_class.new(item_id: 1, option_id: 7),
        described_class.new(item_id: 1, option_id: 5)
      ]

      result = described_class.to_frontend_format(unsorted_options)

      expect(result.first[:option_ids]).to eq([5, 7])
    end

    it 'handles empty array' do
      result = described_class.to_frontend_format([])

      expect(result).to eq([])
    end
  end

  describe '#in_json' do
    it 'converts to VA Profile API request format' do
      json_string = person_option.in_json
      parsed = JSON.parse(json_string)

      expect(parsed).to include(
        'itemId' => person_option.item_id,
        'optionId' => person_option.option_id,
        'effectiveStartDate' => person_option.effective_start_date,
        'sourceDate' => person_option.source_date
      )
    end

    it 'includes effective_end_date when present' do
      end_date = '2025-11-25T00:00:00.000Z'
      option = described_class.new(
        item_id: 1,
        option_id: 5,
        effective_end_date: end_date
      )

      json_string = option.in_json
      parsed = JSON.parse(json_string)

      expect(parsed['effectiveEndDate']).to eq(end_date)
    end
  end

  describe '.to_api_payload' do
    let(:person_options) do
      [
        described_class.new(
          item_id: 1,
          option_id: 5,
          effective_start_date: '2025-11-03T00:00:00Z',
          source_date: '2025-11-03T12:00:00Z'
        ),
        described_class.new(
          item_id: 2,
          option_id: 10,
          effective_end_date: '2025-11-03T00:00:00Z',
          source_date: '2025-11-03T12:00:00Z'
        )
      ]
    end

    it 'formats collection for VA Profile API payload' do
      payload = described_class.to_api_payload(person_options)

      expect(payload).to have_key(:bio)
      expect(payload[:bio]).to have_key(:personOptions)
      expect(payload[:bio][:personOptions].length).to eq(2)
    end
  end

  describe '.build_from' do
    let(:single_option_body) do
      {
        'person_option_id' => 123,
        'item_id' => 4,
        'option_id' => 30,
        'effective_start_date' => '2025-11-25T00:00:00Z',
        'effective_end_date' => nil,
        'source_date' => '2025-11-25T00:00:00Z'
      }
    end

    it 'creates PersonOption from API response hash' do
      option = described_class.build_from(single_option_body)

      expect(option.id).to eq(123)
      expect(option.item_id).to eq(4)
      expect(option.option_id).to eq(30)
      expect(option.effective_start_date).to eq('2025-11-25T00:00:00Z')
      expect(option.effective_end_date).to be_nil
      expect(option.source_date).to eq('2025-11-25T00:00:00Z')
    end
  end

  describe '.build_from_response' do
    it 'creates array of PersonOption instances from API response' do
      options = described_class.build_from_response(api_response_body)

      expect(options.length).to eq(2)
      expect(options).to all(be_a(described_class))
    end

    it 'correctly maps attributes for each option' do
      options = described_class.build_from_response(api_response_body)

      first_option = options.first
      expect(first_option.id).to eq(123)
      expect(first_option.item_id).to eq(4)
      expect(first_option.option_id).to eq(30)

      second_option = options.last
      expect(second_option.id).to eq(456)
      expect(second_option.item_id).to eq(3)
      expect(second_option.option_id).to eq(18)
    end
  end
end
