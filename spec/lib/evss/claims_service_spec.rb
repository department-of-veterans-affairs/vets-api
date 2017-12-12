# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

describe EVSS::ClaimsService do
  let(:current_user) do
    user = FactoryBot.create(
      :user,
      :loa3,
      first_name: 'WESLEY',
      last_name: 'FORD',
      last_signed_in: Time.parse("2017-12-07T00:55:09Z"),
      ssn: '796043735'
    )

    allow(user).to receive(:edipi).and_return('1007697216')
    allow(user).to receive(:birls_id).and_return('796043735')
    allow(user).to receive(:participant_id).and_return('600061742')
    allow(user.va_profile).to receive(:birth_date).and_return('1986-05-06T00:00:00+00:00'.to_date.to_s)
    user
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  let(:claims_service) { described_class.new(auth_headers) }

  subject { claims_service }

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'should get claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette(
        'evss/claims/claims',
        VCR::MATCH_EVERYTHING
      ) do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'should post a 5103 waiver', run_at: 'Tue, 12 Dec 2017 03:21:11 GMT' do
      VCR.use_cassette('evss/claims/set_5103_waiver', VCR::MATCH_EVERYTHING) do
        response = subject.request_decision(evss_id)
        expect(response).to be_success
      end
    end
  end
end
