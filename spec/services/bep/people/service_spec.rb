# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BEP::People::Service do
  let(:user) { create(:user, :loa3, participant_id:) }
  let(:participant_id) { '600061742' }

  before do
    stub_mpi(build(:mpi_profile, participant_id:))
  end

  describe '#find_person_by_participant_id' do
    let(:expected_file_number) { '796043735' }
    let(:expected_participant_id) { user.participant_id }
    let(:status) { :ok }

    it 'returns a bep people response given a participant_id' do
      VCR.use_cassette('bep/people_service/person_data') do
        service = BEP::People::Service.new(user)
        response = service.find_person_by_participant_id

        expect(response.participant_id).to eq(expected_participant_id)
        expect(response.file_number).to eq(expected_file_number)
        expect(response.status).to eq(status)
      end
    end

    context 'no user found' do
      let(:participant_id) { '11111111111' }
      let(:expected_error) { BEP::People::Service::VAFileNumberNotFound.new }
      let(:expected_error_message_icn) { { icn: user.icn } }
      let(:expected_error_message_team) { { team: } }
      let(:team) { 'vfs-ebenefits' }

      it 'returns a bep people response without a found record' do
        VCR.use_cassette('bep/people_service/no_person_data') do
          service = BEP::People::Service.new(user)
          response = service.find_person_by_participant_id

          expect(response.participant_id).to be_nil
          expect(response.file_number).to be_nil
          expect(response.status).to eq(status)
        end
      end

      it 'logs an exception to sentry' do
        VCR.use_cassette('bep/people_service/no_person_data') do
          service = BEP::People::Service.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(expected_error,
                                                                    expected_error_message_icn,
                                                                    expected_error_message_team)
          service.find_person_by_participant_id
        end
      end
    end

    context 'bep server error' do
      let(:server_error) { StandardError }
      let(:expected_error_message_icn) { { icn: user.icn } }
      let(:expected_error_message_team) { { team: } }
      let(:team) { 'vfs-ebenefits' }
      let(:status) { :error }

      before do
        allow_any_instance_of(BEP::Services).to receive(:people).and_raise(server_error)
      end

      it 'logs an exception to sentry' do
        service = BEP::People::Service.new(user)
        expect(service).to receive(:log_exception_to_sentry).with(server_error,
                                                                  expected_error_message_icn,
                                                                  expected_error_message_team)
        service.find_person_by_participant_id
      end

      it 'creates a bep people empty response with status error' do
        service = BEP::People::Service.new(user)
        response = service.find_person_by_participant_id

        expect(response.status).to eq(status)
        expect(response.file_number).to be_nil
      end
    end
  end
end
