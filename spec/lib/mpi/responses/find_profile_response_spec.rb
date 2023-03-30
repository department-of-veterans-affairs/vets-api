# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/find_profile_response'

describe MPI::Responses::FindProfileResponse do
  let(:find_profile_response) { described_class.new(status:, profile:, error:) }
  let(:status) { 'some-status' }
  let(:profile) { 'some-profile' }
  let(:error) { 'some-error' }

  describe '#cache?' do
    subject { find_profile_response.cache? }

    context 'when status is :ok' do
      let(:status) { :ok }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when status is :not_found' do
      let(:status) { :not_found }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when status is an arbitrary value' do
      let(:status) { 'some-status' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#ok?' do
    subject { find_profile_response.ok? }

    context 'when status is :ok' do
      let(:status) { :ok }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when status is not :ok' do
      let(:status) { 'some-status' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#server_error?' do
    subject { find_profile_response.server_error? }

    context 'when status is :server_error' do
      let(:status) { :server_error }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when status is not :server_error' do
      let(:status) { 'some-status' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#not_found?' do
    subject { find_profile_response.not_found? }

    context 'when status is :not_found' do
      let(:status) { :not_found }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when status is not :not_found' do
      let(:status) { 'some-status' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end
end
