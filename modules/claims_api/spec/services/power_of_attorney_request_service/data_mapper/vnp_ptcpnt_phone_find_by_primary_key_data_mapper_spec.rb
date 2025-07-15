# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntPhoneFindByPrimaryKeyDataMapper do
<<<<<<< HEAD
  subject { described_class.new(record:) }

  let(:record) do
    { phone_nbr: '5555559876' }
  end

  let(:expected_response_obj) do
    { 'phone_nbr' => '5555559876' }
  end
=======
  subject { described_class.new(record: record) }

  let(:record) { [] }
>>>>>>> 1e8d0ec948 (WIP)

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      res = subject.call

<<<<<<< HEAD
      expect(res).to eq(expected_response_obj)
    end
  end
end
=======
      expect(res).to eq([])
    end
  end
end
>>>>>>> 1e8d0ec948 (WIP)
