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

  describe 'payment_history:check_empty_history' do
    context 'when no ICN is provided' do
      it 'displays usage message and exits' do
        expect { task.invoke }.to raise_error(SystemExit).and output(/Usage:/).to_stdout
      end
    end

    context 'when ICN is provided' do
      context 'and feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        end

        it 'shows feature flag is enabled' do
          expect { task.invoke(icn) }.to output(/payment_history is ENABLED/).to_stdout
        end

        it 'masks the ICN in output' do
          expect { task.invoke(icn) }.to output(/1234\*/).to_stdout
        end
      end

      context 'and feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)
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

        it 'shows user name from MPI' do
          expect { task.invoke(icn) }.to output(/Name: John Doe/).to_stdout
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
            .and_raise(StandardError.new('Connection timeout'))
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
