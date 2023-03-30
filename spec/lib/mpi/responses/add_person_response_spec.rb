# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/add_person_response'

describe MPI::Responses::AddPersonResponse do
  let(:add_person_response) { described_class.new(status:, parsed_codes:, error:) }
  let(:status) { 'some-status' }
  let(:parsed_codes) { 'some-parsed-codes' }
  let(:error) { 'some-error' }

  describe '#ok?' do
    subject { add_person_response.ok? }

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
    subject { add_person_response.server_error? }

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
end
