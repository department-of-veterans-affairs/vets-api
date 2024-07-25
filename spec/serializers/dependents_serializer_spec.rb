# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsSerializer, type: :serializer do
  subject { serialize(dependents, serializer_class: described_class) }

  let(:person_id) { '600140899' }
  let(:person) do
    {
      award_indicator: 'N',
      date_of_birth: '01/02/1960',
      email_address: 'test@email.com',
      first_name: 'JANE',
      last_name: 'WEBB',
      middle_name: 'M',
      ptcpnt_id: '600140899',
      related_to_vet: 'Y',
      relationship: 'Spouse',
      ssn: '222883214',
      veteran_indicator: 'N'
    }
  end

  let(:expiring_diary) do
    {
      person_id:,
      dependency_decision_type: 'T18',
      dependency_decision_type_description: 'Turns 18',
      dependency_status_type_description: 'Not an Award Dependent',
      award_effective_date: 2.days.from_now.iso8601
    }
  end
  let(:current_diary) do
    {
      person_id:,
      dependency_decision_type: 'EMC',
      dependency_decision_type_description: 'Eligible Minor Child',
      dependency_status_type_description: 'Minor Child',
      award_effective_date: 2.years.ago.iso8601
    }
  end

  let(:dependents) do
    {
      number_of_records: '2',
      persons: [person],
      return_code: 'SHAR 9999',
      return_message: 'Records found',
      diaries: {
        dependency_decs: [expiring_diary,
                          current_diary]
      }
    }
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  context 'when persons is a hash' do
    let(:persons_hash) do
      {
        number_of_records: '2',
        persons: person,
        return_code: 'SHAR 9999',
        return_message: 'Records found',
        diaries: {}
      }
    end
    let(:response_persons_hash) { serialize(persons_hash, serializer_class: described_class) }
    let(:attributes_persons_hash) { JSON.parse(response_persons_hash)['data']['attributes'] }

    it 'includes :persons as an Array' do
      expect(attributes_persons_hash['persons']).to be_a(Array)
      expect(attributes_persons_hash['persons'].size).to eq 1
    end
  end

  context 'when persons is an array' do
    it 'includes :persons' do
      expect(attributes['persons']).to be_a(Array)
      expect(attributes['persons'].size).to eq dependents[:persons].size
    end
  end

  it 'includes person with attributes' do
    expect(attributes['persons'].first).to include(
      'award_indicator' => 'N',
      'date_of_birth' => '01/02/1960',
      'email_address' => 'test@email.com',
      'first_name' => 'JANE',
      'last_name' => 'WEBB',
      'middle_name' => 'M',
      'ptcpnt_id' => '600140899',
      'related_to_vet' => 'Y',
      'relationship' => 'Spouse',
      'ssn' => '222883214',
      'veteran_indicator' => 'N'
    )
  end

  context 'upcoming removal date within range' do
    it 'returns date and reason' do
      expect(attributes['persons'].first).to include('upcoming_removal_date')
      expect(attributes['persons'].first).to include('upcoming_removal_reason' => 'Turns 18')
    end
  end

  context 'upcoming removal expired' do
    let(:expiring_diary) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        dependency_decision_type_description: 'Turns 18',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 2.days.ago.iso8601
      }
    end

    it 'does not return expired date and reason' do
      expect(attributes['persons'].first['upcoming_removal_date']).to be_nil
      expect(attributes['persons'].first['upcoming_removal_reason']).to be_nil
    end

    it 'does not display current benefits date and reason' do
      expect(attributes['persons'].first['dependent_benefit_type']).to be_nil
    end
  end

  context 'current benefits within range' do
    it 'returns benefits description' do
      expect(attributes['persons'].first).to include('dependent_benefit_type' => 'Minor Child')
    end
  end

  context 'current benefits out of range' do
    let(:current_diary) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        dependency_decision_type_description: 'Eligible Minor Child',
        dependency_status_type_description: 'Minor Child',
        award_effective_date: 2.days.from_now.iso8601
      }
    end

    it 'does not return date and reason' do
      expect(attributes['persons'].first['dependent_benefit_type']).to be_nil
    end
  end
end
