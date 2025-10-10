# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::VnpPtcpntPhoneFindByPrimaryKeyDataGatherer do
  subject { described_class.new(record:) }

  let(:record) do
    { phone_nbr: '5555559876' }
  end

  let(:expected_response_obj) do
    { 'phone_nbr' => '5555559876' }
  end

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      res = subject.call

      expect(res).to eq(expected_response_obj)
    end

    context 'when international phone number is present' do
      let(:record) do
        { frgn_phone_rfrnc_txt: '442012345678', phone_nbr: nil }
      end

      let(:expected_response_obj) do
        { 'phone_nbr' => '442012345678' }
      end

      it 'uses frgn_phone_rfrnc_txt when phone_nbr is nil' do
        res = subject.call

        expect(res).to eq(expected_response_obj)
      end
    end

    context 'when both phone fields are present' do
      let(:record) do
        { frgn_phone_rfrnc_txt: '442012345678', phone_nbr: '5555559876' }
      end

      let(:expected_response_obj) do
        { 'phone_nbr' => '442012345678' }
      end

      it 'prefers frgn_phone_rfrnc_txt over phone_nbr' do
        res = subject.call

        expect(res).to eq(expected_response_obj)
      end
    end
  end
end
