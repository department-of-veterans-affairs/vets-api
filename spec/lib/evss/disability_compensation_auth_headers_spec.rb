# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_auth_headers'

describe EVSS::DisabilityCompensationAuthHeaders do
  let(:auth_headers) { { foo: 'bar' } }
  subject { described_class }

  it 'includes gender in the headers' do
    user = build(:user)
    expect(subject.add_headers(auth_headers, user)).to eq(foo: 'bar', gender: 'MALE')
  end

  it 'raises an error if gender is not included' do
    user = build(:blank_gender_user)
    expect { subject.add_headers(auth_headers, user) }.to raise_error(Common::Exceptions::UnprocessableEntity)
  end
end
