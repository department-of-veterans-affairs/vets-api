# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::People::Response do
  let(:response) do
    {
      ptcpnt_id: participant_id,
      file_nbr: file_number,
      ssn_nbr: ssn_number
    }
  end
  let(:participant_id) { 'some-participant-id' }
  let(:file_number) { 'some-file-number' }
  let(:ssn_number) { 'some-ssn-number' }

  describe '#participant_id' do
    subject { described_class.new(response).participant_id }

    context 'when response is present' do
      it 'returns ptcpnt_id field on the response' do
        expect(subject).to eq(participant_id)
      end
    end

    context 'when response is not present' do
      let(:response) { nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end

  describe '#file_number' do
    subject { described_class.new(response).file_number }

    context 'when response is present' do
      it 'returns file_nbr field on the response' do
        expect(subject).to eq(file_number)
      end
    end

    context 'when response is not present' do
      let(:response) { nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end

  describe '#ssn_number' do
    subject { described_class.new(response).ssn_number }

    context 'when response is present' do
      it 'returns ssn_nbr field on the response' do
        expect(subject).to eq(ssn_number)
      end
    end

    context 'when response is not present' do
      let(:response) { nil }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end

  describe '#cache?' do
    subject { described_class.new(response, status:).cache? }

    context 'when status is ok' do
      let(:status) { :ok }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when status is not ok' do
      let(:status) { :error }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end
end
