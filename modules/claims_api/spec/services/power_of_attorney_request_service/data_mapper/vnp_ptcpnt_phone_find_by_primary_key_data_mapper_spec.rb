# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntPhoneFindByPrimaryKeyDataMapper do
  subject { described_class.new(record: record) }

  let(:record) { [] }

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      res = subject.call

      expect(res).to eq([])
    end
  end
end