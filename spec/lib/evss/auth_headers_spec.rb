# frozen_string_literal: true
require 'rails_helper'
require 'evss/auth_headers'

describe EVSS::AuthHeaders do
  let(:current_user) { FactoryGirl.create(:loa3_user) }

  subject { described_class.new(current_user) }

  it 'has the right LoA' do
    expect(subject.to_h['va_eauth_assurancelevel']).to eq '3'
  end
end
