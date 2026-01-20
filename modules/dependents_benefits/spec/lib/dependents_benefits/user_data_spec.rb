# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/user_data'

RSpec.describe DependentsBenefits::UserData do
  let(:user) do
    double(
      'User',
      first_name: 'John',
      middle_name: 'Michael',
      last_name: 'Doe',
      ssn: '123456789',
      uuid: 'user-uuid-123',
      birth_date: '1980-01-01',
      common_name: 'John Doe',
      email: 'john.doe@example.com',
      icn: 'icn-123',
      participant_id: 'participant-123',
      va_profile_email: 'john.doe@va.gov'
    )
  end

  let(:claim_data) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'Jane',
          'middle' => 'Marie',
          'last' => 'Smith'
        },
        'birth_date' => '1985-05-15'
      },
      'veteran_contact_information' => {
        'email_address' => 'jane.smith@example.com'
      },
      'file_number' => 'claim-file-123'
    }
  end

  let(:bgs_service) { double('BGS::Services') }
  let(:bgs_people) { double('BGS::People') }
  let(:monitor) { double('DependentsBenefits::Monitor') }

  before do
    allow(BGS::Services).to receive(:new).and_return(bgs_service)
    allow(bgs_service).to receive(:people).and_return(bgs_people)
    allow(bgs_people).to receive_messages(find_person_by_ptcpnt_id: nil, find_by_ssn: nil)
    allow(DependentsBenefits::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_user_data_error)
    allow(monitor).to receive(:track_user_data_warning)
  end

  describe '#initialize' do
    context 'with valid user and claim data' do
      it 'initializes with user data taking precedence' do
        user_data = described_class.new(user, claim_data)

        expect(user_data.first_name).to eq('John')
        expect(user_data.middle_name).to eq('Michael')
        expect(user_data.last_name).to eq('Doe')
        expect(user_data.ssn).to eq('123456789')
        expect(user_data.uuid).to eq('user-uuid-123')
        expect(user_data.birth_date).to eq('1980-01-01')
        expect(user_data.common_name).to eq('John Doe')
        expect(user_data.email).to eq('john.doe@example.com')
        expect(user_data.icn).to eq('icn-123')
        expect(user_data.participant_id).to eq('participant-123')
        expect(user_data.notification_email).to eq('john.doe@va.gov')
      end
    end

    context 'with missing user data' do
      let(:incomplete_user) do
        double(
          'User',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          ssn: '123456789',
          uuid: 'user-uuid-123',
          birth_date: nil,
          common_name: 'John Doe',
          email: nil,
          icn: 'icn-123',
          participant_id: 'participant-123',
          va_profile_email: 'john.doe@va.gov'
        )
      end

      it 'falls back to claim data' do
        user_data = described_class.new(incomplete_user, claim_data)

        expect(user_data.first_name).to eq('Jane')
        expect(user_data.middle_name).to eq('Marie')
        expect(user_data.last_name).to eq('Smith')
        expect(user_data.birth_date).to eq('1985-05-15')
        expect(user_data.email).to eq('jane.smith@example.com')
      end
    end

    context 'when file number lookup succeeds' do
      before do
        allow(bgs_people).to receive(:find_person_by_ptcpnt_id).with('participant-123', '123456789')
                                                               .and_return({ file_nbr: '987-65-4321' })
      end

      it 'sets va_file_number from BGS' do
        user_data = described_class.new(user, claim_data)
        expect(user_data.va_file_number).to eq('987654321')
      end
    end

    context 'when file number lookup fails' do
      before do
        allow(bgs_people).to receive_messages(find_person_by_ptcpnt_id: nil, find_by_ssn: nil)
      end

      it 'falls back to ssn' do
        user_data = described_class.new(user, claim_data)
        expect(user_data.va_file_number).to eq('123456789')
      end
    end

    context 'when initialization fails' do
      before do
        allow(user).to receive(:first_name).and_raise(StandardError, 'Database error')
      end

      it 'tracks error and raises UnprocessableEntity' do
        expect(monitor).to receive(:track_user_data_error).with(
          'DependentsBenefits::UserData#initialize error',
          'user_hash.failure',
          { error: instance_of(StandardError) }
        )

        expect do
          described_class.new(user, claim_data)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe '#get_user_json' do
    before do
      allow(bgs_people).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '987654321' })
    end

    it 'returns valid JSON with veteran information' do
      user_data = described_class.new(user, claim_data)
      json_string = user_data.get_user_json
      parsed_json = JSON.parse(json_string)

      veteran_info = parsed_json['veteran_information']
      expect(veteran_info['full_name']['first']).to eq('John')
      expect(veteran_info['full_name']['middle']).to eq('Michael')
      expect(veteran_info['full_name']['last']).to eq('Doe')
      expect(veteran_info['common_name']).to eq('John Doe')
      expect(veteran_info['va_profile_email']).to eq('john.doe@va.gov')
      expect(veteran_info['email']).to eq('john.doe@example.com')
      expect(veteran_info['participant_id']).to eq('participant-123')
      expect(veteran_info['ssn']).to eq('123456789')
      expect(veteran_info['va_file_number']).to eq('987654321')
      expect(veteran_info['birth_date']).to eq('1980-01-01')
      expect(veteran_info['uuid']).to eq('user-uuid-123')
      expect(veteran_info['icn']).to eq('icn-123')
    end

    it 'compacts nil values from full_name' do
      user_without_middle = double(
        'User',
        first_name: 'John',
        middle_name: nil,
        last_name: 'Doe',
        ssn: '123456789',
        uuid: 'user-uuid-123',
        birth_date: '1980-01-01',
        common_name: 'John Doe',
        email: 'john.doe@example.com',
        icn: 'icn-123',
        participant_id: 'participant-123',
        va_profile_email: 'john.doe@va.gov'
      )

      claim_data_with_no_middle = claim_data.dup
      claim_data_with_no_middle['veteran_information']['full_name'].delete('middle')
      user_data = described_class.new(user_without_middle, claim_data_with_no_middle)
      json_string = user_data.get_user_json
      parsed_json = JSON.parse(json_string)

      full_name = parsed_json['veteran_information']['full_name']
      expect(full_name).to eq({ 'first' => 'John', 'last' => 'Doe' })
      expect(full_name).not_to have_key('middle')
    end

    context 'when JSON generation fails' do
      let(:user_data) { described_class.new(user, claim_data) }

      before do
        allow(user_data).to receive(:first_name).and_raise(StandardError, 'Encoding error')
      end

      it 'tracks error and raises UnprocessableEntity' do
        expect(monitor).to receive(:track_user_data_error).with(
          'DependentsBenefits::UserData#get_user_hash error',
          'user_hash.failure',
          { error: instance_of(StandardError) }
        )

        expect do
          user_data.get_user_json
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe '#get_file_number' do
    let(:user_data) { described_class.new(user, claim_data) }

    context 'when BGS returns file number with dashes' do
      before do
        allow(bgs_people).to receive(:find_person_by_ptcpnt_id).with('participant-123', '123456789')
                                                               .and_return({ file_nbr: '123-45-6789' })
      end

      it 'strips dashes from file number' do
        file_number = user_data.send(:get_file_number)
        expect(file_number).to eq('123456789')
      end
    end

    context 'when BGS returns normal file number' do
      before do
        allow(bgs_people).to receive(:find_person_by_ptcpnt_id).with('participant-123', '123456789')
                                                               .and_return({ file_nbr: '987654321' })
      end

      it 'returns file number as-is' do
        file_number = user_data.send(:get_file_number)
        expect(file_number).to eq('987654321')
      end
    end

    context 'when participant ID lookup fails but SSN lookup succeeds' do
      before do
        allow(bgs_people).to receive(:find_person_by_ptcpnt_id).and_return(nil)
        allow(bgs_people).to receive(:find_by_ssn).with('123456789')
                                                  .and_return({ file_nbr: '555666777' })
      end

      it 'falls back to SSN lookup' do
        file_number = user_data.send(:get_file_number)
        expect(file_number).to eq('555666777')
      end
    end

    context 'when both BGS lookups fail' do
      before do
        allow(bgs_people).to receive_messages(find_person_by_ptcpnt_id: nil, find_by_ssn: nil)
      end

      it 'tracks warning and returns nil' do
        expect(monitor).to receive(:track_user_data_warning).with(
          'DependentsBenefits::UserData#get_file_number error',
          'file_number_lookup.failure',
          { error: 'Could not retrieve file number from BGS' }
        )

        file_number = user_data.send(:get_file_number)
        expect(file_number).to be_nil
      end
    end

    context 'when BGS service raises an exception' do
      before do
        allow(bgs_people).to receive(:find_person_by_ptcpnt_id).and_raise(StandardError, 'BGS timeout')
      end

      it 'tracks warning and returns nil' do
        expect(monitor).to receive(:track_user_data_warning).with(
          'DependentsBenefits::UserData#get_file_number error',
          'file_number_lookup.failure',
          { error: 'Could not retrieve file number from BGS' }
        )

        file_number = user_data.send(:get_file_number)
        expect(file_number).to be_nil
      end
    end
  end

  describe '#service' do
    let(:user_data) { described_class.new(user, claim_data) }

    it 'creates BGS service with ICN and external key' do
      expect(BGS::Services).to receive(:new).with(
        external_uid: 'icn-123',
        external_key: 'John Doe'
      ).and_return(bgs_service)

      expect(user_data.send(:service)).to eq(bgs_service)
    end

    it 'memoizes the service instance' do
      service1 = user_data.send(:service)
      service2 = user_data.send(:service)
      expect(service1).to eq(service2)
    end
  end

  describe '#external_key' do
    let(:user_data) { described_class.new(user, claim_data) }

    context 'when common_name is present' do
      it 'uses common_name' do
        expect(user_data.send(:external_key)).to eq('John Doe')
      end
    end

    context 'when common_name is blank but email is present' do
      let(:user_without_common_name) do
        double(
          'User',
          first_name: 'John',
          middle_name: 'Michael',
          last_name: 'Doe',
          ssn: '123456789',
          uuid: 'user-uuid-123',
          birth_date: '1980-01-01',
          common_name: '',
          email: 'john.doe@example.com',
          icn: 'icn-123',
          participant_id: 'participant-123',
          va_profile_email: 'john.doe@va.gov'
        )
      end

      it 'falls back to email' do
        user_data = described_class.new(user_without_common_name, claim_data)
        expect(user_data.send(:external_key)).to eq('john.doe@example.com')
      end
    end

    context 'when external key exceeds max length' do
      let(:long_name_user) do
        double(
          'User',
          first_name: 'John',
          middle_name: 'Michael',
          last_name: 'Doe',
          ssn: '123456789',
          uuid: 'user-uuid-123',
          birth_date: '1980-01-01',
          common_name: 'A' * 100,
          email: 'john.doe@example.com',
          icn: 'icn-123',
          participant_id: 'participant-123',
          va_profile_email: 'john.doe@va.gov'
        )
      end

      before do
        stub_const('BGS::Constants::EXTERNAL_KEY_MAX_LENGTH', 10)
      end

      it 'truncates to max length' do
        user_data = described_class.new(long_name_user, claim_data)
        expect(user_data.send(:external_key)).to eq('A' * 10)
      end
    end
  end

  describe '#get_user_email' do
    let(:user_data) { described_class.new(user, claim_data) }

    context 'when user.va_profile_email succeeds' do
      it 'returns va_profile_email with presence check' do
        expect(user_data.send(:get_user_email, user)).to eq('john.doe@va.gov')
      end

      context 'when va_profile_email is blank' do
        let(:user_with_blank_email) do
          double(
            'User',
            first_name: 'John',
            middle_name: 'Michael',
            last_name: 'Doe',
            ssn: '123456789',
            uuid: 'user-uuid-123',
            birth_date: '1980-01-01',
            common_name: 'John Doe',
            email: 'john.doe@example.com',
            icn: 'icn-123',
            participant_id: 'participant-123',
            va_profile_email: ''
          )
        end

        it 'returns nil for blank email' do
          expect(user_data.send(:get_user_email, user_with_blank_email)).to be_nil
        end
      end
    end

    context 'when user.va_profile_email raises an exception' do
      let(:error_user) do
        double(
          'User',
          first_name: 'John',
          middle_name: 'Michael',
          last_name: 'Doe',
          ssn: '123456789',
          uuid: 'user-uuid-123',
          birth_date: '1980-01-01',
          common_name: 'John Doe',
          email: 'john.doe@example.com',
          icn: 'icn-123',
          participant_id: 'participant-123'
        )
      end

      before do
        allow(error_user).to receive(:va_profile_email).and_raise(StandardError, 'VAProfile service error')
      end

      it 'tracks warning and returns nil' do
        expect(monitor).to receive(:track_user_data_warning).with(
          'DependentsBenefits::UserData#get_user_email failed to get va_profile_email',
          'get_va_profile_email.failure',
          { error: 'VAProfile service error' }
        )

        result = user_data.send(:get_user_email, error_user)
        expect(result).to be_nil
      end
    end
  end

  describe 'notification_email behavior' do
    context 'when va_profile_email is available' do
      it 'sets notification_email to va_profile_email' do
        user_data = described_class.new(user, claim_data)
        expect(user_data.notification_email).to eq('john.doe@va.gov')
      end
    end

    context 'when va_profile_email fails and form email is available' do
      let(:error_user) do
        double(
          'User',
          first_name: 'John',
          middle_name: 'Michael',
          last_name: 'Doe',
          ssn: '123456789',
          uuid: 'user-uuid-123',
          birth_date: '1980-01-01',
          common_name: 'John Doe',
          email: 'john.doe@example.com',
          icn: 'icn-123',
          participant_id: 'participant-123'
        )
      end

      before do
        allow(error_user).to receive(:va_profile_email).and_raise(StandardError, 'VAProfile service error')
      end

      it 'falls back to form email for notification_email' do
        expect(monitor).to receive(:track_user_data_warning)

        user_data = described_class.new(error_user, claim_data)
        expect(user_data.notification_email).to eq('john.doe@example.com')
      end
    end
  end

  describe '#monitor' do
    let(:user_data) { described_class.new(user, claim_data) }

    it 'creates DependentsBenefits::Monitor instance' do
      expect(DependentsBenefits::Monitor).to receive(:new).and_return(monitor)
      expect(user_data.send(:monitor)).to eq(monitor)
    end

    it 'memoizes the monitor instance' do
      monitor1 = user_data.send(:monitor)
      monitor2 = user_data.send(:monitor)
      expect(monitor1).to eq(monitor2)
    end
  end
end
