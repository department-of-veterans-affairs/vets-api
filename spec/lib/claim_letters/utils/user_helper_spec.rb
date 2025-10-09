# frozen_string_literal: true

require 'rails_helper'
require 'claim_letters/utils/user_helper'

RSpec.describe ClaimLetters::Utils::UserHelper do
  # Shared user class for testing Object-type users
  let(:user_class) do
    Class.new do
      attr_accessor :file_number, :ssn, :participant_id

      def initialize(file_number: nil, ssn: nil, participant_id: nil)
        @file_number = file_number
        @ssn = ssn
        @participant_id = participant_id
      end
    end
  end

  describe '.safe_get' do
    context 'when user is a Hash' do
      context 'with symbol keys' do
        let(:user) { { file_number: '123456', ssn: '987654321', participant_id: 'P123' } }

        it 'retrieves value using symbol key' do
          expect(described_class.safe_get(user, :file_number)).to eq('123456')
        end

        it 'retrieves value when attribute is passed as string' do
          expect(described_class.safe_get(user, 'file_number')).to eq('123456')
        end

        it 'returns nil for non-existent key' do
          expect(described_class.safe_get(user, :non_existent)).to be_nil
        end
      end

      context 'with string keys' do
        let(:user) { { 'file_number' => '123456', 'ssn' => '987654321', 'participant_id' => 'P123' } }

        it 'retrieves value using string key' do
          expect(described_class.safe_get(user, 'file_number')).to eq('123456')
        end

        it 'retrieves value when attribute is passed as symbol' do
          expect(described_class.safe_get(user, :file_number)).to eq('123456')
        end

        it 'returns nil for non-existent key' do
          expect(described_class.safe_get(user, :non_existent)).to be_nil
        end
      end

      context 'with mixed keys' do
        let(:user) { { file_number: '123456', 'ssn' => '987654321' } }

        it 'retrieves symbol key with symbol attribute' do
          expect(described_class.safe_get(user, :file_number)).to eq('123456')
        end

        it 'retrieves string key with string attribute' do
          expect(described_class.safe_get(user, 'ssn')).to eq('987654321')
        end
      end

      context 'with nil or blank values' do
        let(:user) { { file_number: nil, ssn: '', participant_id: '   ' } }

        it 'returns nil for nil value' do
          expect(described_class.safe_get(user, :file_number)).to be_nil
        end

        it 'returns empty string for empty string value' do
          expect(described_class.safe_get(user, :ssn)).to eq('')
        end

        it 'returns whitespace string as-is' do
          expect(described_class.safe_get(user, :participant_id)).to eq('   ')
        end
      end
    end

    context 'when user is an Object' do
      let(:user) { user_class.new(file_number: '123456', ssn: '987654321', participant_id: 'P123') }

      it 'retrieves value using public_send' do
        expect(described_class.safe_get(user, :file_number)).to eq('123456')
      end

      it 'works with string attribute name' do
        expect(described_class.safe_get(user, 'ssn')).to eq('987654321')
      end

      it 'returns nil for non-existent method' do
        expect(described_class.safe_get(user, :non_existent_method)).to be_nil
      end

      context 'with nil values' do
        let(:user) { user_class.new }

        it 'returns nil for nil attribute' do
          expect(described_class.safe_get(user, :file_number)).to be_nil
        end
      end

      context 'with private methods' do
        let(:user_class) do
          Class.new do
            def initialize
              @secret = 'private_data'
            end

            private

            attr_reader :secret
          end
        end

        let(:user) { user_class.new }

        it 'returns nil for private methods' do
          expect(described_class.safe_get(user, :secret)).to be_nil
        end
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nil' do
        expect(described_class.safe_get(user, :file_number)).to be_nil
        expect(described_class.safe_get(user, :ssn)).to be_nil
        expect(described_class.safe_get(user, :participant_id)).to be_nil
      end
    end

    context 'when user is an unexpected type' do
      it 'handles string gracefully' do
        expect(described_class.safe_get('string', :file_number)).to be_nil
      end

      it 'handles integer gracefully' do
        expect(described_class.safe_get(123, :file_number)).to be_nil
      end

      it 'handles array gracefully' do
        expect(described_class.safe_get([], :file_number)).to be_nil
      end
    end
  end

  describe '.local_file_number' do
    context 'when user is a Hash' do
      context 'when file_number is present' do
        let(:user) { { file_number: '123456', ssn: '987654321' } }

        it 'returns file_number' do
          expect(described_class.local_file_number(user)).to eq('123456')
        end
      end

      context 'when file_number is blank but ssn is present' do
        let(:user) { { file_number: '', ssn: '987654321' } }

        it 'returns ssn' do
          expect(described_class.local_file_number(user)).to eq('987654321')
        end
      end

      context 'when file_number is nil but ssn is present' do
        let(:user) { { file_number: nil, ssn: '987654321' } }

        it 'returns ssn' do
          expect(described_class.local_file_number(user)).to eq('987654321')
        end
      end

      context 'when both are blank' do
        let(:user) { { file_number: '', ssn: '' } }

        it 'returns empty string' do
          expect(described_class.local_file_number(user)).to eq('')
        end
      end

      context 'when both are nil' do
        let(:user) { {} }

        it 'returns nil' do
          expect(described_class.local_file_number(user)).to be_nil
        end
      end
    end

    context 'when user is an Object' do
      context 'when file_number is present' do
        let(:user) { user_class.new(file_number: '123456', ssn: '987654321') }

        it 'returns file_number' do
          expect(described_class.local_file_number(user)).to eq('123456')
        end
      end

      context 'when file_number is nil but ssn is present' do
        let(:user) { user_class.new(ssn: '987654321') }

        it 'returns ssn' do
          expect(described_class.local_file_number(user)).to eq('987654321')
        end
      end
    end

    context 'when user is nil' do
      it 'returns nil' do
        expect(described_class.local_file_number(nil)).to be_nil
      end
    end
  end

  describe '.remote_file_number' do
    let(:bgs_request) { instance_double(BGS::People::Request) }
    let(:bgs_response) { double('BGS Response', file_number: '999888777') }

    before do
      allow(BGS::People::Request).to receive(:new).and_return(bgs_request)
    end

    context 'when BGS call succeeds' do
      before do
        allow(bgs_request).to receive(:find_person_by_participant_id).and_return(bgs_response)
      end

      context 'with file_number present' do
        it 'returns the file_number' do
          user = { participant_id: 'P123' }
          expect(described_class.remote_file_number(user)).to eq('999888777')
        end
      end

      context 'with blank file_number' do
        let(:bgs_response) { double('BGS Response', file_number: '') }

        it 'returns nil' do
          user = { participant_id: 'P123' }
          expect(described_class.remote_file_number(user)).to be_nil
        end
      end

      context 'with nil file_number' do
        let(:bgs_response) { double('BGS Response', file_number: nil) }

        it 'returns nil' do
          user = { participant_id: 'P123' }
          expect(described_class.remote_file_number(user)).to be_nil
        end
      end
    end

    context 'when BGS call raises an error' do
      before do
        allow(bgs_request).to receive(:find_person_by_participant_id).and_raise(StandardError, 'BGS Error')
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns nil' do
        user = { participant_id: 'P123' }
        expect(described_class.remote_file_number(user)).to be_nil
      end

      it 'logs the error' do
        user = { participant_id: 'P123' }
        described_class.remote_file_number(user)
        expect(Rails.logger).to have_received(:warn).with('Failed to fetch remote file number: BGS Error')
      end
    end

    context 'when user is an Object' do
      let(:user) { user_class.new(participant_id: 'P123') }

      before do
        allow(bgs_request).to receive(:find_person_by_participant_id).with(user:).and_return(bgs_response)
      end

      it 'passes the user object correctly to BGS' do
        expect(described_class.remote_file_number(user)).to eq('999888777')
        expect(bgs_request).to have_received(:find_person_by_participant_id).with(user:)
      end
    end
  end

  describe '.file_number' do
    let(:bgs_request) { instance_double(BGS::People::Request) }

    before do
      allow(BGS::People::Request).to receive(:new).and_return(bgs_request)
    end

    context 'when participant_id is blank' do
      context 'with Hash user' do
        let(:user) { { file_number: '123456', ssn: '987654321' } }

        it 'returns local_file_number without calling BGS' do
          expect(bgs_request).not_to receive(:find_person_by_participant_id)
          expect(described_class.file_number(user)).to eq('123456')
        end
      end

      context 'with Object user' do
        let(:user) { user_class.new(file_number: '123456', ssn: '987654321') }

        it 'returns local_file_number without calling BGS' do
          expect(bgs_request).not_to receive(:find_person_by_participant_id)
          expect(described_class.file_number(user)).to eq('123456')
        end
      end

      context 'when participant_id is empty string' do
        let(:user) { { participant_id: '', file_number: '123456' } }

        it 'returns local_file_number' do
          expect(bgs_request).not_to receive(:find_person_by_participant_id)
          expect(described_class.file_number(user)).to eq('123456')
        end
      end

      context 'when participant_id is whitespace' do
        let(:user) { { participant_id: '   ', file_number: '123456' } }

        it 'returns local_file_number' do
          expect(bgs_request).not_to receive(:find_person_by_participant_id)
          expect(described_class.file_number(user)).to eq('123456')
        end
      end
    end

    context 'when participant_id is present' do
      let(:bgs_response) { double('BGS Response', file_number: '999888777') }

      before do
        allow(bgs_request).to receive(:find_person_by_participant_id).and_return(bgs_response)
      end

      context 'when remote_file_number returns a value' do
        let(:user) { { participant_id: 'P123', ssn: '987654321' } }

        it 'returns remote_file_number' do
          expect(described_class.file_number(user)).to eq('999888777')
        end
      end

      context 'when remote_file_number returns nil' do
        let(:bgs_response) { double('BGS Response', file_number: nil) }
        let(:user) { { participant_id: 'P123', ssn: '987654321' } }

        it 'falls back to ssn' do
          expect(described_class.file_number(user)).to eq('987654321')
        end
      end

      context 'when remote_file_number returns empty string' do
        let(:bgs_response) { double('BGS Response', file_number: '') }
        let(:user) { { participant_id: 'P123', ssn: '987654321' } }

        it 'falls back to ssn' do
          expect(described_class.file_number(user)).to eq('987654321')
        end
      end

      context 'when BGS call fails' do
        before do
          allow(bgs_request).to receive(:find_person_by_participant_id).and_raise(StandardError, 'BGS Error')
          allow(Rails.logger).to receive(:warn)
        end

        let(:user) { { participant_id: 'P123', ssn: '987654321' } }

        it 'falls back to ssn' do
          expect(described_class.file_number(user)).to eq('987654321')
        end
      end
    end

    context 'edge cases' do
      context 'when user is nil' do
        it 'returns nil' do
          expect(described_class.file_number(nil)).to be_nil
        end
      end

      context 'when user has no identifiers' do
        let(:user) { {} }

        it 'returns nil' do
          expect(described_class.file_number(user)).to be_nil
        end
      end

      context 'when all identifiers are blank' do
        let(:user) { { participant_id: '', file_number: '', ssn: '' } }

        it 'returns empty string' do
          expect(described_class.file_number(user)).to eq('')
        end
      end
    end

    context 'integration test with different user types' do
      let(:bgs_response) { double('BGS Response', file_number: '999888777') }

      before do
        allow(bgs_request).to receive(:find_person_by_participant_id).and_return(bgs_response)
      end

      it 'handles Object with methods' do
        user = user_class.new(participant_id: 'P123', ssn: '987654321')
        expect(described_class.file_number(user)).to eq('999888777')
      end

      it 'handles OpenStruct' do
        user = OpenStruct.new(participant_id: 'P123', ssn: '987654321')
        expect(described_class.file_number(user)).to eq('999888777')
      end
    end
  end
end
