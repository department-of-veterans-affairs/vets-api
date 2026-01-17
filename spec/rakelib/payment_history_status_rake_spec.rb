# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'payment_history:check_empty_history rake task', type: :task do
  before(:all) do
    Rake.application.rake_require '../rakelib/payment_history_status'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['payment_history:check_empty_history'] }
  let(:icn) { '1234567890V123456' }

  before do
    task.reenable
  end

  describe '#mask_value' do
    let(:rake_context) do
      Class.new do
        include Rake::DSL
        Rake.application.rake_require '../rakelib/payment_history_status'
      end.new
    end

    context 'when value is nil' do
      it 'returns "nil"' do
        result = rake_context.send(:mask_value, nil)
        expect(result).to eq('nil')
      end
    end

    context 'when value length is less than or equal to visible_start' do
      it 'returns the original value for exact length match' do
        result = rake_context.send(:mask_value, '1234', visible_start: 4)
        expect(result).to eq('1234')
      end

      it 'returns the original value for shorter strings' do
        result = rake_context.send(:mask_value, 'abc', visible_start: 4)
        expect(result).to eq('abc')
      end

      it 'returns empty string unchanged' do
        result = rake_context.send(:mask_value, '', visible_start: 4)
        expect(result).to eq('')
      end
    end

    context 'with default parameters (visible_start: 4, visible_end: 0)' do
      it 'masks everything after first 4 characters' do
        result = rake_context.send(:mask_value, '1234567890')
        expect(result).to eq('1234******')
      end

      it 'masks a long string correctly' do
        result = rake_context.send(:mask_value, '1234567890ABCDEF')
        expect(result).to eq('1234************')
      end

      it 'masks string with exactly 5 characters' do
        result = rake_context.send(:mask_value, '12345')
        expect(result).to eq('1234*')
      end
    end

    context 'with custom visible_start' do
      it 'shows only first 2 characters' do
        result = rake_context.send(:mask_value, '1234567890', visible_start: 2)
        expect(result).to eq('12********')
      end

      it 'shows first 6 characters' do
        result = rake_context.send(:mask_value, '1234567890', visible_start: 6)
        expect(result).to eq('123456****')
      end

      it 'shows first 3 characters' do
        result = rake_context.send(:mask_value, 'abcdefgh', visible_start: 3)
        expect(result).to eq('abc*****')
      end
    end

    context 'with custom visible_end' do
      it 'shows last 4 characters' do
        result = rake_context.send(:mask_value, '1234567890', visible_start: 4, visible_end: 4)
        expect(result).to eq('1234**7890')
      end

      it 'shows last 3 characters' do
        result = rake_context.send(:mask_value, 'test@email.com', visible_start: 4, visible_end: 4)
        expect(result).to eq('test******.com')
      end

      it 'handles zero visible_end explicitly' do
        result = rake_context.send(:mask_value, '1234567890', visible_start: 4, visible_end: 0)
        expect(result).to eq('1234******')
      end
    end

    context 'with both visible_start and visible_end' do
      it 'masks middle portion with 3 visible at start and 4 at end' do
        result = rake_context.send(:mask_value, 'secret@email.com', visible_start: 6, visible_end: 4)
        expect(result).to eq('secret******.com')
      end

      it 'handles SSN-like format with dashes' do
        result = rake_context.send(:mask_value, '123-45-6789', visible_start: 0, visible_end: 4)
        expect(result).to eq('*******6789')
      end

      it 'handles ICN-like identifiers' do
        result = rake_context.send(:mask_value, '1234567890V123456', visible_start: 4, visible_end: 0)
        expect(result).to eq('1234*************')
      end
    end

    context 'edge cases' do
      it 'handles single character string' do
        result = rake_context.send(:mask_value, 'a', visible_start: 4)
        expect(result).to eq('a')
      end

      it 'handles string where visible_start + visible_end equals length' do
        result = rake_context.send(:mask_value, '12345', visible_start: 2, visible_end: 3)
        expect(result).to eq('12345')
      end

      it 'handles string where visible_start + visible_end is greater than length' do
        result = rake_context.send(:mask_value, '123', visible_start: 2, visible_end: 3)
        expect(result).to eq('123')
      end

      it 'masks entire middle for exact boundaries' do
        result = rake_context.send(:mask_value, '1234567890', visible_start: 3, visible_end: 3)
        expect(result).to eq('123****890')
      end
    end

    context 'real-world examples' do
      it 'masks email addresses' do
        result = rake_context.send(:mask_value, 'user@example.com', visible_start: 4, visible_end: 4)
        expect(result).to eq('user********.com')
      end

      it 'masks phone numbers' do
        result = rake_context.send(:mask_value, '555-123-4567', visible_start: 4, visible_end: 4)
        expect(result).to eq('555-****4567')
      end

      it 'masks credit card numbers' do
        result = rake_context.send(:mask_value, '4111111111111111', visible_start: 4, visible_end: 4)
        expect(result).to eq('4111********1111')
      end
    end
  end

  describe '#mask_icn' do
    let(:rake_context) do
      Class.new do
        include Rake::DSL
        Rake.application.rake_require '../rakelib/payment_history_status'
      end.new
    end

    it 'uses mask_value with default ICN parameters' do
      result = rake_context.send(:mask_icn, '1234567890V123456')
      expect(result).to eq('1234*************')
    end

    it 'handles nil ICN' do
      result = rake_context.send(:mask_icn, nil)
      expect(result).to eq('nil')
    end

    it 'handles short ICN' do
      result = rake_context.send(:mask_icn, '123')
      expect(result).to eq('123')
    end
  end

  describe '#mask_first_name' do
    let(:rake_context) do
      Class.new do
        include Rake::DSL
        Rake.application.rake_require '../rakelib/payment_history_status'
      end.new
    end

    it 'masks first name showing only first character' do
      result = rake_context.send(:mask_first_name, 'John')
      expect(result).to eq('J***')
    end

    it 'masks longer first name' do
      result = rake_context.send(:mask_first_name, 'Alexander')
      expect(result).to eq('A********')
    end

    it 'handles short first name' do
      result = rake_context.send(:mask_first_name, 'J')
      expect(result).to eq('J')
    end

    it 'handles nil first name' do
      result = rake_context.send(:mask_first_name, nil)
      expect(result).to eq('nil')
    end

    it 'handles empty first name' do
      result = rake_context.send(:mask_first_name, '')
      expect(result).to eq('')
    end

    it 'masks two-character first name' do
      result = rake_context.send(:mask_first_name, 'Bo')
      expect(result).to eq('B*')
    end
  end

  describe '#mask_last_name' do
    let(:rake_context) do
      Class.new do
        include Rake::DSL
        Rake.application.rake_require '../rakelib/payment_history_status'
      end.new
    end

    it 'masks last name showing only first character' do
      result = rake_context.send(:mask_last_name, 'Doe')
      expect(result).to eq('D**')
    end

    it 'masks longer last name' do
      result = rake_context.send(:mask_last_name, 'Washington')
      expect(result).to eq('W*********')
    end

    it 'masks hyphenated last name' do
      result = rake_context.send(:mask_last_name, 'Smith-Jones')
      expect(result).to eq('S**********')
    end

    it 'handles short last name' do
      result = rake_context.send(:mask_last_name, 'O')
      expect(result).to eq('O')
    end

    it 'handles nil last name' do
      result = rake_context.send(:mask_last_name, nil)
      expect(result).to eq('nil')
    end

    it 'handles empty last name' do
      result = rake_context.send(:mask_last_name, '')
      expect(result).to eq('')
    end

    it 'masks two-character last name' do
      result = rake_context.send(:mask_last_name, 'Wu')
      expect(result).to eq('W*')
    end
  end

  describe '#mask_file_number' do
    let(:rake_context) do
      Class.new do
        include Rake::DSL
        Rake.application.rake_require '../rakelib/payment_history_status'
      end.new
    end

    it 'masks file number showing only last 4 digits' do
      result = rake_context.send(:mask_file_number, '123456789')
      expect(result).to eq('*****6789')
    end

    it 'masks file number as string' do
      result = rake_context.send(:mask_file_number, '987654321')
      expect(result).to eq('*****4321')
    end

    it 'masks file number as integer' do
      result = rake_context.send(:mask_file_number, 123_456_789)
      expect(result).to eq('*****6789')
    end

    it 'handles short file number (less than 4 characters)' do
      result = rake_context.send(:mask_file_number, '123')
      expect(result).to eq('123')
    end

    it 'handles exactly 4 character file number' do
      result = rake_context.send(:mask_file_number, '1234')
      expect(result).to eq('1234')
    end

    it 'handles nil file number' do
      result = rake_context.send(:mask_file_number, nil)
      expect(result).to eq('nil')
    end

    it 'masks longer file number correctly' do
      result = rake_context.send(:mask_file_number, '12345678901234')
      expect(result).to eq('**********1234')
    end

    it 'handles file number with exactly 5 digits' do
      result = rake_context.send(:mask_file_number, '12345')
      expect(result).to eq('*2345')
    end
  end

  describe '#mask_participant_id' do
    let(:rake_context) do
      Class.new do
        include Rake::DSL
        Rake.application.rake_require '../rakelib/payment_history_status'
      end.new
    end

    it 'masks participant ID showing first 3 and last 2 digits' do
      result = rake_context.send(:mask_participant_id, '600061742')
      expect(result).to eq('600****42')
    end

    it 'masks another participant ID' do
      result = rake_context.send(:mask_participant_id, '600012345')
      expect(result).to eq('600****45')
    end

    it 'masks participant ID as integer' do
      result = rake_context.send(:mask_participant_id, 600_061_742)
      expect(result).to eq('600****42')
    end

    it 'handles short participant ID (5 characters or less)' do
      result = rake_context.send(:mask_participant_id, '12345')
      expect(result).to eq('12345')
    end

    it 'handles exactly 5 character participant ID' do
      result = rake_context.send(:mask_participant_id, '60012')
      expect(result).to eq('60012')
    end

    it 'handles nil participant ID' do
      result = rake_context.send(:mask_participant_id, nil)
      expect(result).to eq('nil')
    end

    it 'masks longer participant ID correctly' do
      result = rake_context.send(:mask_participant_id, '123456789012')
      expect(result).to eq('123*******12')
    end

    it 'handles exactly 6 character participant ID' do
      result = rake_context.send(:mask_participant_id, '600123')
      expect(result).to eq('600*23')
    end

    it 'handles participant ID as string' do
      result = rake_context.send(:mask_participant_id, '987654321')
      expect(result).to eq('987****21')
    end
  end

  describe 'payment_history:check_empty_history' do
    context 'when no ICN is provided' do
      it 'displays usage message and exits' do
        expect { task.invoke }.to raise_error(SystemExit).and output(/Usage:/).to_stdout
      end
    end

    context 'when ICN is provided' do
      context 'and feature flag is enabled' do
        let(:mpi_service) { instance_double(MPI::Service) }
        let(:mpi_profile) { build(:mpi_profile, icn:) }
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
          allow(MPI::Service).to receive(:new).and_return(mpi_service)
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows feature flag is enabled' do
          expect { task.invoke(icn) }.to output(/payment_history is ENABLED/).to_stdout
        end

        it 'masks the ICN in output' do
          expect { task.invoke(icn) }.to output(/1234\*/).to_stdout
        end
      end

      context 'and feature flag is disabled' do
        let(:mpi_service) { instance_double(MPI::Service) }
        let(:mpi_profile) { build(:mpi_profile, icn:) }
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)
          allow(MPI::Service).to receive(:new).and_return(mpi_service)
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows feature flag is disabled' do
          expect { task.invoke(icn) }.to output(/payment_history is DISABLED/).to_stdout
        end

        it 'provides instructions to enable' do
          expect { task.invoke(icn) }.to output(/Flipper.enable/).to_stdout
        end
      end
    end

    describe 'check_user_exists' do
      let(:mpi_service) { instance_double(MPI::Service) }

      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        allow(MPI::Service).to receive(:new).and_return(mpi_service)
      end

      context 'when user account exists and MPI profile is found' do
        let!(:user_account) { create(:user_account, icn:) }
        let(:mpi_profile) { build(:mpi_profile, icn:, given_names: ['John'], family_name: 'Doe') }
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows UserAccount found' do
          expect { task.invoke(icn) }.to output(/✓ UserAccount found/).to_stdout
        end

        it 'shows user verification status' do
          expect { task.invoke(icn) }.to output(/Verified: true/).to_stdout
        end

        it 'shows MPI profile found' do
          expect { task.invoke(icn) }.to output(/✓ User found in MPI/).to_stdout
        end

        it 'shows user name from MPI (masked)' do
          expect { task.invoke(icn) }.to output(/Name: J\*\*\* D\*\*/).to_stdout
        end
      end

      context 'when user account does not exist' do
        let(:mpi_profile) { build(:mpi_profile, icn:) }
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows UserAccount not found' do
          expect { task.invoke(icn) }.to output(/✗ UserAccount not found in database/).to_stdout
        end

        it 'provides helpful message' do
          expect { task.invoke(icn) }.to output(/User may not have logged in or ICN may be incorrect/).to_stdout
        end

        it 'still shows MPI profile found' do
          expect { task.invoke(icn) }.to output(/✓ User found in MPI/).to_stdout
        end
      end

      context 'when user account exists but MPI profile is not found' do
        let!(:user_account) { create(:user_account, icn:) }
        let(:find_profile_response) { create(:find_profile_not_found_response) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows UserAccount found' do
          expect { task.invoke(icn) }.to output(/✓ UserAccount found/).to_stdout
        end

        it 'shows MPI profile not found' do
          expect { task.invoke(icn) }.to output(/✗ User not found in MPI/).to_stdout
        end

        it 'provides helpful message about MPI' do
          expect do
            task.invoke(icn)
          end.to output(/ICN may be invalid or user may not exist in Master Person Index/).to_stdout
        end
      end

      context 'when neither user account nor MPI profile exist' do
        let(:find_profile_response) { create(:find_profile_not_found_response) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows both not found' do
          expect { task.invoke(icn) }
            .to output(/✗ UserAccount not found in database.*✗ User not found in MPI/m).to_stdout
        end
      end

      context 'when MPI service raises an error' do
        let!(:user_account) { create(:user_account, icn:) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .and_raise(Faraday::Error.new('Connection timeout'))
        end

        it 'shows UserAccount found' do
          expect { task.invoke(icn) }.to output(/✓ UserAccount found/).to_stdout
        end

        it 'shows error querying MPI' do
          expect { task.invoke(icn) }.to output(/✗ Error querying MPI: Connection timeout/).to_stdout
        end
      end

      context 'when MPI returns server error response' do
        let!(:user_account) { create(:user_account, icn:) }
        let(:find_profile_response) { create(:find_profile_server_error_response) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows MPI lookup failed' do
          expect { task.invoke(icn) }.to output(/✗ MPI lookup failed/).to_stdout
        end
      end
    end

    describe 'check_policy_attributes' do
      let(:mpi_service) { instance_double(MPI::Service) }

      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        allow(MPI::Service).to receive(:new).and_return(mpi_service)
      end

      context 'when user has all required attributes' do
        let(:mpi_profile) do
          build(:mpi_profile,
                icn:,
                ssn: '123456789',
                participant_id: '600061742',
                given_names: ['John'],
                family_name: 'Doe')
        end
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows all attributes are present' do
          expect { task.invoke(icn) }
            .to output(/✓ ICN present.*✓ SSN present.*✓ Participant ID present/m).to_stdout
        end

        it 'shows policy access granted' do
          expect { task.invoke(icn) }.to output(/✓ User has all required attributes for BGS policy access/).to_stdout
        end

        it 'masks SSN in output' do
          expect { task.invoke(icn) }.to output(/\*\*\*-\*\*-6789/).to_stdout
        end
      end

      context 'when user is missing ICN' do
        let(:mpi_profile) do
          build(:mpi_profile,
                icn: nil,
                ssn: '123456789',
                participant_id: '600061742')
        end
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows ICN missing' do
          expect { task.invoke(icn) }.to output(/✗ ICN missing/).to_stdout
        end

        it 'shows policy access denied' do
          expect { task.invoke(icn) }.to output(/✗ User is missing required attributes for BGS policy access/).to_stdout
        end

        it 'provides explanation' do
          expect { task.invoke(icn) }.to output(/BGS policy requires ICN to be present/).to_stdout
        end
      end

      context 'when user is missing SSN' do
        let(:mpi_profile) do
          build(:mpi_profile,
                icn:,
                ssn: nil,
                participant_id: '600061742')
        end
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows SSN missing' do
          expect { task.invoke(icn) }.to output(/✗ SSN missing/).to_stdout
        end

        it 'shows policy access denied' do
          expect { task.invoke(icn) }.to output(/✗ User is missing required attributes for BGS policy access/).to_stdout
        end

        it 'provides explanation' do
          expect { task.invoke(icn) }.to output(/BGS policy requires SSN to be present/).to_stdout
        end
      end

      context 'when user is missing Participant ID' do
        let(:mpi_profile) do
          build(:mpi_profile,
                icn:,
                ssn: '123456789',
                participant_id: nil)
        end
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows Participant ID missing' do
          expect { task.invoke(icn) }.to output(/✗ Participant ID missing/).to_stdout
        end

        it 'shows policy access denied' do
          expect { task.invoke(icn) }.to output(/✗ User is missing required attributes for BGS policy access/).to_stdout
        end

        it 'provides explanation' do
          expect { task.invoke(icn) }.to output(/BGS policy requires Participant ID to be present/).to_stdout
        end
      end

      context 'when user is missing multiple attributes' do
        let(:mpi_profile) do
          build(:mpi_profile,
                icn: nil,
                ssn: nil,
                participant_id: '600061742')
        end
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows all missing attributes' do
          expect { task.invoke(icn) }
            .to output(/✗ ICN missing.*✗ SSN missing/m).to_stdout
        end

        it 'shows policy access denied' do
          expect { task.invoke(icn) }.to output(/✗ User is missing required attributes for BGS policy access/).to_stdout
        end

        it 'explains payment history will be denied' do
          expect { task.invoke(icn) }.to output(/Payment history will be denied due to missing attributes/).to_stdout
        end
      end
    end

    describe '#check_bgs_file_number' do
      let(:mpi_profile) do
        build(:mpi_profile,
              icn: '1234567890V123456',
              ssn: '123456789',
              participant_id: '600012345')
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        mpi_service = instance_double(MPI::Service)
        allow(MPI::Service).to receive(:new).and_return(mpi_service)
        response = build(:find_profile_response, profile: mpi_profile)
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(response)
      end

      context 'when BGS person lookup succeeds with file number' do
        it 'shows success and file number present' do
          VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
            expect { task.invoke(icn) }.to output(/BGS person lookup succeeded.*File number present/m).to_stdout
          end
        end
      end

      context 'when BGS person lookup succeeds but file number is missing' do
        it 'shows file number missing warning' do
          person = OpenStruct.new(
            status: :ok,
            file_number: nil,
            participant_id: '600012345',
            ssn_number: '123456789'
          )

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          expect do
            task.invoke(icn)
          end.to output(/File number missing.*Payment history requires a valid file number/m).to_stdout
        end
      end

      context 'when BGS person lookup fails with error status' do
        it 'shows error status message' do
          person = OpenStruct.new(status: :error)

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          expect { task.invoke(icn) }.to output(/BGS person lookup failed with error status/m).to_stdout
        end
      end

      context 'when BGS person lookup fails with no_id status' do
        it 'shows no ID found message' do
          person = OpenStruct.new(status: :no_id)

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          expect { task.invoke(icn) }.to output(/BGS person lookup failed - no ID found/m).to_stdout
        end
      end

      context 'when BGS person lookup raises an exception' do
        it 'shows error message' do
          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_raise(StandardError,
                                                                                  'BGS connection failed')

          expect { task.invoke(icn) }.to output(/Error calling BGS person lookup: BGS connection failed/m).to_stdout
        end
      end
    end

    describe '#check_payment_history' do
      let(:mpi_profile) do
        build(:mpi_profile,
              icn: '1234567890V123456',
              ssn: '123456789',
              participant_id: '600012345')
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        mpi_service = instance_double(MPI::Service)
        allow(MPI::Service).to receive(:new).and_return(mpi_service)
        response = build(:find_profile_response, profile: mpi_profile)
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(response)
      end

      context 'when BGS has payment records' do
        it 'shows payment records found' do
          VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
            VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
              expect { task.invoke(icn) }.to output(/Payment records found: 47 payment\(s\)/m).to_stdout
            end
          end
        end
      end

      context 'when BGS returns nil response' do
        it 'shows nil response message' do
          person = OpenStruct.new(
            status: :ok,
            file_number: '123456789',
            participant_id: '600012345',
            ssn_number: '123456789'
          )

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return(nil)

          expect { task.invoke(icn) }.to output(/BGS returned nil response.*No payment records available/m).to_stdout
        end
      end

      context 'when BGS returns response without payments key' do
        it 'shows no payments found message' do
          person = OpenStruct.new(
            status: :ok,
            file_number: '123456789',
            participant_id: '600012345',
            ssn_number: '123456789'
          )

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({})

          expect { task.invoke(icn) }.to output(/No payments found in response.*BGS has no payment records/m).to_stdout
        end
      end

      context 'when BGS returns empty payments array' do
        it 'shows payments array is empty message' do
          person = OpenStruct.new(
            status: :ok,
            file_number: '123456789',
            participant_id: '600012345',
            ssn_number: '123456789'
          )

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: [] } })

          expect { task.invoke(icn) }.to output(/Payments array is empty.*BGS has no payment records/m).to_stdout
        end
      end

      context 'when BGS payment history raises an exception' do
        it 'shows error message' do
          person = OpenStruct.new(
            status: :ok,
            file_number: '123456789',
            participant_id: '600012345',
            ssn_number: '123456789'
          )

          bgs_service = instance_double(BGS::People::Request)
          allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
          allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_raise(StandardError,
                                                                        'BGS payment service unavailable')

          expect do
            task.invoke(icn)
          end.to output(/Error calling BGS payment history: BGS payment service unavailable/m).to_stdout
        end
      end
    end

    describe '#check_payment_history_filters' do
      let(:mpi_profile) do
        build(:mpi_profile,
              icn: '1234567890V123456',
              ssn: '123456789',
              participant_id: '600012345')
      end

      let(:person) do
        OpenStruct.new(
          status: :ok,
          file_number: '123456789',
          participant_id: '600012345',
          ssn_number: '123456789'
        )
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        mpi_service = instance_double(MPI::Service)
        allow(MPI::Service).to receive(:new).and_return(mpi_service)
        response = build(:find_profile_response, profile: mpi_profile)
        allow(mpi_service).to receive(:find_profile_by_identifier).and_return(response)

        bgs_service = instance_double(BGS::People::Request)
        allow(BGS::People::Request).to receive(:new).and_return(bgs_service)
        allow(bgs_service).to receive(:find_person_by_participant_id).and_return(person)
      end

      context 'when all payments pass filters (no third-party payments)' do
        it 'shows no payments are filtered' do
          payments = [
            {
              payee_type: 'Person',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600012345'
            },
            {
              payee_type: 'Person',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600012345'
            }
          ]

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: payments } })

          expected_output = /
            ✓\ Would\ NOT\ be\ filtered
            .*Total\ payments:\ 2
            .*Filtered\ out:\ 0
            .*Would\ be\ returned:\ 2
            .*✓\ No\ payments\ are\ being\ filtered
          /mx
          expect { task.invoke(icn) }
            .to output(expected_output)
            .to_stdout
        end
      end

      context 'when payments are filtered by Third Party/Vendor payee type' do
        it 'shows payments filtered by payee type' do
          payments = [
            {
              payee_type: 'Third Party/Vendor',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600012345'
            }
          ]

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: payments } })

          expect { task.invoke(icn) }
            .to output(%r{✗ FILTERED: Payee type is 'Third Party/Vendor'})
            .to_stdout
        end
      end

      context 'when payments are filtered by mismatched participant IDs' do
        it 'shows payments filtered by ID mismatch' do
          payments = [
            {
              payee_type: 'Person',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600099999'
            }
          ]

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: payments } })

          expect { task.invoke(icn) }
            .to output(/✗ FILTERED: Beneficiary and Recipient IDs don't match/)
            .to_stdout
        end
      end

      context 'when all payments are filtered out' do
        it 'shows all payments filtered warning' do
          payments = [
            {
              payee_type: 'Third Party/Vendor',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600012345'
            },
            {
              payee_type: 'Person',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600099999'
            }
          ]

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: payments } })

          expected_output = /
            Total\ payments:\ 2
            .*Filtered\ out:\ 2
            .*Would\ be\ returned:\ 0
            .*✗\ All\ payments\ are\ being\ filtered\ out!
            .*This\ is\ why\ payment\ history\ appears\ empty
          /mx

          expect { task.invoke(icn) }
            .to output(expected_output)
            .to_stdout
        end
      end

      context 'when some payments are filtered out' do
        it 'shows partial filtering warning' do
          payments = [
            {
              payee_type: 'Person',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600012345'
            },
            {
              payee_type: 'Third Party/Vendor',
              beneficiary_participant_id: '600012345',
              recipient_participant_id: '600012345'
            }
          ]

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: payments } })

          expected_output = /
            Total\ payments:\ 2
            .*Filtered\ out:\ 1
            .*Would\ be\ returned:\ 1
            .*⚠\ Some\ payments\ are\ being\ filtered\ out
          /mx
          expect { task.invoke(icn) }
            .to output(expected_output)
            .to_stdout
        end
      end

      context 'when payment is a single hash (not array)' do
        it 'handles single payment correctly' do
          payment = {
            payee_type: 'Person',
            beneficiary_participant_id: '600012345',
            recipient_participant_id: '600012345'
          }

          payment_service = instance_double(BGS::PaymentService)
          allow(BGS::PaymentService).to receive(:new).and_return(payment_service)
          allow(payment_service).to receive(:payment_history).and_return({ payments: { payment: } })

          expect { task.invoke(icn) }
            .to output(/Total payments: 1.*Filtered out: 0.*Would be returned: 1/m)
            .to_stdout
        end
      end
    end
  end
end
