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
  end
end
