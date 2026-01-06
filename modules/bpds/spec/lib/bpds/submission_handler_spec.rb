# frozen_string_literal: true

require 'rails_helper'
require 'bpds/submission_handler'

RSpec.describe BPDS::SubmissionHandler do
  let(:controller_class) do
    Class.new do
      include BPDS::SubmissionHandler
      attr_accessor :current_user
    end
  end

  let(:controller) { controller_class.new }
  let(:claim) { build(:burials_saved_claim) }
  let(:bpds_monitor) { instance_double(BPDS::Monitor) }
  let(:user) { nil }

  before do
    controller.current_user = user
    allow(BPDS::Monitor).to receive(:new).and_return(bpds_monitor)
    allow(bpds_monitor).to receive_messages(
      track_submit_begun: nil,
      track_skip_bpds_job: nil,
      track_get_user_identifier: nil,
      track_get_user_identifier_result: nil,
      track_get_user_identifier_file_number_result: nil
    )
    allow(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async)
  end

  describe '#submit_claim_to_bpds' do
    context 'when feature flag is disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(false) }

      it 'returns false without submitting' do
        expect(BPDS::Sidekiq::SubmitToBPDSJob).not_to receive(:perform_async)
        expect(controller.submit_claim_to_bpds(claim)).to be false
      end
    end

    context 'when no user identifier found' do
      before { allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(true) }

      it 'tracks skip event and returns false' do
        expect(bpds_monitor).to receive(:track_skip_bpds_job).with(claim.id)
        expect(controller.submit_claim_to_bpds(claim)).to be false
      end
    end

    context 'when participant_id found via MPI' do
      let(:user) { build(:user, :loa3, icn: '1008596379V859838') }
      let(:mpi_response) { build(:find_profile_response, profile: build(:mpi_profile, participant_id: '600123456')) }

      before do
        allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(true)
        allow(MPI::Service).to receive(:new).and_return(double(find_profile_by_identifier: mpi_response))
        allow(KmsEncrypted::Box).to receive(:new).and_return(double(encrypt: 'encrypted'))
      end

      it 'queues job with encrypted payload' do
        expect(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async).with(claim.id, 'encrypted')
        expect(controller.submit_claim_to_bpds(claim)).to be true
      end
    end

    context 'when file_number found via BGS' do
      let(:user) { build(:user, :loa1, ssn: '796111863') }
      let(:bgs_response) { BGS::People::Response.new({ file_nbr: '987654321' }) }

      before do
        allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(true)
        allow(BGS::People::Request).to receive(:new).and_return(double(find_person_by_participant_id: bgs_response))
        allow(KmsEncrypted::Box).to receive(:new).and_return(double(encrypt: 'encrypted'))
      end

      it 'queues job with encrypted payload' do
        expect(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async).with(claim.id, 'encrypted')
        expect(controller.submit_claim_to_bpds(claim)).to be true
      end
    end
  end

  describe '#retrieve_identifier_from_mpi' do
    let(:user) { build(:user, :loa3, icn: '1008596379V859838') }

    it 'returns participant_id when found' do
      mpi_response = build(:find_profile_response, profile: build(:mpi_profile, participant_id: '600123456'))
      allow(MPI::Service).to receive(:new).and_return(double(find_profile_by_identifier: mpi_response))

      result = controller.send(:retrieve_identifier_from_mpi)
      expect(result).to eq({ participant_id: '600123456' })
    end

    it 'returns nil when not found' do
      mpi_response = build(:find_profile_response, profile: build(:mpi_profile, participant_id: nil))
      allow(MPI::Service).to receive(:new).and_return(double(find_profile_by_identifier: mpi_response))

      result = controller.send(:retrieve_identifier_from_mpi)
      expect(result).to be_nil
    end
  end

  describe '#retrieve_identifier_from_bgs' do
    it 'returns nil when user is nil' do
      expect(controller.send(:retrieve_identifier_from_bgs)).to be_nil
    end

    context 'with user' do
      let(:user) { build(:user, :loa1, ssn: '796111863') }

      it 'returns participant_id when found' do
        bgs_response = BGS::People::Response.new({ ptcpnt_id: '700123456' })
        allow(BGS::People::Request).to receive(:new).and_return(double(find_person_by_participant_id: bgs_response))

        result = controller.send(:retrieve_identifier_from_bgs)
        expect(result).to eq({ participant_id: '700123456' })
      end

      it 'returns file_number when participant_id not found' do
        bgs_response = BGS::People::Response.new({ file_nbr: '987654321' })
        allow(BGS::People::Request).to receive(:new).and_return(double(find_person_by_participant_id: bgs_response))

        result = controller.send(:retrieve_identifier_from_bgs)
        expect(result).to eq({ file_number: '987654321' })
      end

      it 'returns nil when neither found' do
        bgs_response = BGS::People::Response.new({})
        allow(BGS::People::Request).to receive(:new).and_return(double(find_person_by_participant_id: bgs_response))

        result = controller.send(:retrieve_identifier_from_bgs)
        expect(result).to be_nil
      end
    end
  end
end
