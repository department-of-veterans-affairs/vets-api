# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::VnpPtcpntPhoneFindByPrimaryKeyDataGatherer do
  subject { described_class.new(record:) }

  context 'Mapping the POA data object' do
    context 'domestic phone number' do
      let(:record) do
        { phone_nbr: '5555559876' }
      end

      let(:expected_response_obj) do
        { 'phone_nbr' => '5555559876' }
      end

      it 'gathers the expected data based on the params' do
        res = subject.call

        expect(res).to eq(expected_response_obj)
      end
    end

    context 'international phone number' do
      let(:record) do
        {
          phone_nbr: ' ',
          frgn_phone_rfrnc_txt: '221234 5555'
        }
      end

      let(:expected_response_obj) do
        { 'phone_nbr' => '221234 5555' }
      end

      it 'gathers the expected data based on the params' do
        res = subject.call

        expect(res).to eq(expected_response_obj)
      end
    end
  end
end
