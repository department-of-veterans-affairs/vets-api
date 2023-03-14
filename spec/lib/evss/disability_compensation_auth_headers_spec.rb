# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_auth_headers'

describe EVSS::DisabilityCompensationAuthHeaders do
  let(:auth_headers) { { 'foo' => 'bar' } }
  let(:user) { build(:user) }
  let(:blank_gender_user) { build(:user, :loa3, gender: '') }
  let(:valid_headers) { described_class.new(user) }
  let(:unknown_gender_headers) { described_class.new(blank_gender_user) }

  # rubocop:disable all
  it 'includes gender and birth date in the headers' do
    expect(valid_headers.add_headers(auth_headers)).to eq(
      'foo' => 'bar',
      'va_eauth_authorization' =>
        '{"authorizationResponse":{"status":"VETERAN","idType":"SSN","id":"796111863","edi":null,"firstName":"abraham","lastName":"lincoln","birthDate":"1809-02-12T00:00:00+00:00","gender":"MALE"}}')
  end
  # rubocop:enable all

  it 'gender is unknown if gender is not included' do
    gender = JSON.parse(unknown_gender_headers.add_headers(auth_headers)['va_eauth_authorization']).dig(
      'authorizationResponse', 'gender'
    )
    expect(gender).to eq('UNKNOWN')
  end
end
