# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::People::Request do
  let(:user) { create(:user, :loa3, participant_id:) }
  let(:participant_id) { '600061742' }

  before do
    stub_mpi(build(:mpi_profile, participant_id:))
  end

  describe '#find_person_by_participant_id' do
    subject { BGS::People::Request.new.find_person_by_participant_id(user:) }

    let(:expected_file_number) { '796043735' }
    let(:expected_participant_id) { user.participant_id }
    let(:expected_status) { :ok }

    context 'when user has a participant id' do
      let(:participant_id) { '600061742' }

      context 'and user is found in bgs' do
        it 'returns a bgs people response' do
          VCR.use_cassette('bgs/people_service/person_data') do
            response = subject

            expect(response.participant_id).to eq(expected_participant_id)
            expect(response.file_number).to eq(expected_file_number)
            expect(response.status).to eq(expected_status)
          end
        end

        it 'caches the filled response' do
          VCR.use_cassette('bgs/people_service/person_data') do
            subject
          end
          cached_response = BGS::People::Request.find(participant_id).response
          expect(cached_response.cache?).to be(true)
          expect(cached_response.status).to eq(expected_status)
          expect(cached_response.participant_id).to eq(expected_participant_id)
        end
      end

      context 'and user is not found in bgs' do
        let(:participant_id) { '11111111111' }

        it 'returns a bgs people response without a found record' do
          VCR.use_cassette('bgs/people_service/no_person_data') do
            response = subject
            expect(response.cache?).to be(true)
            expect(response.status).to eq(expected_status)
            expect(response.participant_id).to be_nil
          end
        end

        it 'caches the empty response' do
          VCR.use_cassette('bgs/people_service/no_person_data') do
            subject
          end

          cached_response = BGS::People::Request.find(participant_id).response
          expect(cached_response.cache?).to be(true)
          expect(cached_response.status).to eq(expected_status)
          expect(cached_response.participant_id).to be_nil
        end
      end

      context 'and bgs returns a server error' do
        let(:server_error) { StandardError }
        let(:expected_status) { :error }

        before do
          allow_any_instance_of(BGS::Services).to receive(:people).and_raise(server_error)
        end

        it 'returns a bgs people response without a found record' do
          expect(subject.participant_id).to be_nil
          expect(subject.status).to eq(expected_status)
          expect(subject.cache?).to be(false)
        end

        it 'does not cache the response' do
          subject

          expect(BGS::People::Request.find(participant_id)).to be_nil
        end
      end
    end

    context 'when user does not have a participant id' do
      let(:participant_id) { nil }
      let(:expected_status) { :no_id }

      it 'returns a bgs people response without a found record' do
        expect(subject.participant_id).to be_nil
        expect(subject.status).to eq(expected_status)
        expect(subject.cache?).to be(false)
      end
    end
  end
end
