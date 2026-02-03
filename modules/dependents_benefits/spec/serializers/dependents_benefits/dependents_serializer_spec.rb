# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::DependentsSerializer, type: :serializer do
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
      award_effective_date: 2.days.from_now.iso8601,
      award_event_id: 'EVENT123'
    }
  end
  let(:current_diary) do
    {
      person_id:,
      dependency_decision_type: 'EMC',
      dependency_decision_type_description: 'Eligible Minor Child',
      dependency_status_type_description: 'Minor Child',
      award_effective_date: 2.years.ago.iso8601,
      award_event_id: 'EVENT123'
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

  it 'includes :type as dependents' do
    expect(data['type']).to eq('dependents')
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

  context 'whitespace normalization' do
    let(:expiring_diary) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        dependency_decision_type_description: 'Turns   18',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 2.days.from_now.iso8601,
        award_event_id: 'EVENT123'
      }
    end
    let(:current_diary) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        dependency_decision_type_description: 'Eligible Minor Child',
        dependency_status_type_description: "Minor  \n Child",
        award_effective_date: 2.years.ago.iso8601,
        award_event_id: 'EVENT123'
      }
    end

    it 'normalizes whitespace in upcoming_removal_reason' do
      expect(attributes['persons'].first['upcoming_removal_reason']).to eq('Turns 18')
    end

    it 'normalizes whitespace in dependent_benefit_type' do
      expect(attributes['persons'].first['dependent_benefit_type']).to eq('Minor Child')
    end
  end

  context 'upcoming removal expired' do
    let(:expiring_diary) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        dependency_decision_type_description: 'Turns 18',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 2.days.ago.iso8601,
        award_event_id: 'EVENT123'
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
        award_effective_date: 2.days.from_now.iso8601,
        award_event_id: 'EVENT123'
      }
    end

    it 'does not return date and reason' do
      expect(attributes['persons'].first['dependent_benefit_type']).to be_nil
    end
  end

  context 'school attendance events' do
    let(:school_attendance_begins) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTB',
        dependency_decision_type_description: 'School Attendance Begins',
        dependency_status_type_description: 'School Attendance',
        award_effective_date: 1.year.ago.iso8601,
        award_event_id: 'EVENT456'
      }
    end
    let(:school_attendance_terminates) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTT',
        dependency_decision_type_description: 'School Attendance Terminates',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 3.months.from_now.iso8601,
        award_event_id: 'EVENT456'
      }
    end
    let(:dependents) do
      {
        number_of_records: '1',
        persons: [person],
        return_code: 'SHAR 9999',
        return_message: 'Records found',
        diaries: {
          dependency_decs: [school_attendance_begins, school_attendance_terminates]
        }
      }
    end

    it 'sets benefit type from SCHATTB event' do
      expect(attributes['persons'].first['dependent_benefit_type']).to eq('School Attendance')
    end

    it 'sets upcoming removal from SCHATTT event' do
      expect(attributes['persons'].first).to include('upcoming_removal_date')
      expect(attributes['persons'].first['upcoming_removal_reason']).to eq('School Attendance Terminates')
    end
  end

  context 'multiple persons' do
    let(:person2_id) { '600140900' }
    let(:person2) do
      {
        award_indicator: 'Y',
        date_of_birth: '05/15/2010',
        first_name: 'JOHN',
        last_name: 'WEBB',
        middle_name: 'D',
        ptcpnt_id: person2_id,
        related_to_vet: 'Y',
        relationship: 'Child',
        veteran_indicator: 'N'
      }
    end
    let(:person2_current) do
      {
        person_id: person2_id,
        dependency_decision_type: 'EMC',
        dependency_decision_type_description: 'Eligible Minor Child',
        dependency_status_type_description: 'Minor Child',
        award_effective_date: 3.years.ago.iso8601,
        award_event_id: 'EVENT789'
      }
    end
    let(:person2_expiring) do
      {
        person_id: person2_id,
        dependency_decision_type: 'T18',
        dependency_decision_type_description: 'Turns 18',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 1.year.from_now.iso8601,
        award_event_id: 'EVENT789'
      }
    end
    let(:dependents) do
      {
        number_of_records: '2',
        persons: [person, person2],
        return_code: 'SHAR 9999',
        return_message: 'Records found',
        diaries: {
          dependency_decs: [current_diary, expiring_diary, person2_current, person2_expiring]
        }
      }
    end

    it 'returns all persons' do
      expect(attributes['persons'].size).to eq(2)
    end

    it 'enriches each person with their own decisions' do
      person1_data = attributes['persons'].find { |p| p['ptcpnt_id'] == person_id }
      person2_data = attributes['persons'].find { |p| p['ptcpnt_id'] == person2_id }

      expect(person1_data['dependent_benefit_type']).to eq('Minor Child')
      expect(person1_data['upcoming_removal_reason']).to eq('Turns 18')

      expect(person2_data['dependent_benefit_type']).to eq('Minor Child')
      expect(person2_data['upcoming_removal_reason']).to eq('Turns 18')
    end
  end

  context 'multiple END_EVENTS for same person' do
    let(:earlier_end_event) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        dependency_decision_type_description: 'Turns 18',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 1.month.from_now.iso8601,
        award_event_id: 'EVENT123'
      }
    end
    let(:later_end_event) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTT',
        dependency_decision_type_description: 'School Attendance Terminates',
        dependency_status_type_description: 'Not an Award Dependent',
        award_effective_date: 6.months.from_now.iso8601,
        award_event_id: 'EVENT123'
      }
    end
    let(:dependents) do
      {
        number_of_records: '1',
        persons: [person],
        return_code: 'SHAR 9999',
        return_message: 'Records found',
        diaries: {
          dependency_decs: [current_diary, earlier_end_event, later_end_event]
        }
      }
    end

    it 'uses the most recent END_EVENT' do
      expect(attributes['persons'].first['upcoming_removal_reason']).to eq('School Attendance Terminates')
    end
  end

  context 'person with no matching decisions' do
    let(:person2_id) { '600140900' }
    let(:person2) do
      {
        award_indicator: 'N',
        first_name: 'JOHN',
        last_name: 'DOE',
        ptcpnt_id: person2_id,
        relationship: 'Child'
      }
    end
    let(:dependents) do
      {
        number_of_records: '2',
        persons: [person, person2],
        return_code: 'SHAR 9999',
        return_message: 'Records found',
        diaries: {
          dependency_decs: [current_diary, expiring_diary]
        }
      }
    end

    it 'does not add decision fields to person without matching decisions' do
      person2_data = attributes['persons'].find { |p| p['ptcpnt_id'] == person2_id }

      expect(person2_data['upcoming_removal_date']).to be_nil
      expect(person2_data['upcoming_removal_reason']).to be_nil
      expect(person2_data['dependent_benefit_type']).to be_nil
    end
  end

  context 'empty or nil diaries' do
    context 'when diaries has empty dependency_decs' do
      let(:dependents) do
        {
          number_of_records: '1',
          persons: [person],
          return_code: 'SHAR 9999',
          return_message: 'Records found',
          diaries: { dependency_decs: [] }
        }
      end

      it 'returns persons without enrichment' do
        expect(attributes['persons'].first['ptcpnt_id']).to eq(person_id)
        expect(attributes['persons'].first['upcoming_removal_date']).to be_nil
        expect(attributes['persons'].first['dependent_benefit_type']).to be_nil
      end
    end

    context 'when diaries has nil dependency_decs' do
      let(:dependents) do
        {
          number_of_records: '1',
          persons: [person],
          return_code: 'SHAR 9999',
          return_message: 'Records found',
          diaries: { dependency_decs: nil }
        }
      end

      it 'returns persons without enrichment' do
        expect(attributes['persons'].first['ptcpnt_id']).to eq(person_id)
        expect(attributes['persons'].first['upcoming_removal_date']).to be_nil
        expect(attributes['persons'].first['dependent_benefit_type']).to be_nil
      end
    end

    context 'when diaries is not a hash' do
      let(:dependents) do
        {
          number_of_records: '1',
          persons: [person],
          return_code: 'SHAR 9999',
          return_message: 'Records found',
          diaries: 'invalid'
        }
      end

      it 'returns persons without enrichment' do
        expect(attributes['persons'].first['ptcpnt_id']).to eq(person_id)
        expect(attributes['persons'].first['upcoming_removal_date']).to be_nil
        expect(attributes['persons'].first['dependent_benefit_type']).to be_nil
      end
    end
  end

  context 'preserves all person fields' do
    it 'includes all original person attributes' do
      person_data = attributes['persons'].first

      expect(person_data).to include(
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
  end
end
