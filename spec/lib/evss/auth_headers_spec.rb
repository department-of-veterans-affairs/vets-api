# frozen_string_literal: true

require 'rails_helper'
require 'evss/auth_headers'

describe EVSS::AuthHeaders do
  subject { described_class.new(current_user) }

  context 'with an LoA3 user' do
    let(:current_user) { FactoryBot.build(:user, :loa3) }

    it 'has the right LoA' do
      expect(subject.to_h['va_eauth_assurancelevel']).to eq '3'
    end

    it 'has only lowercase first letters in key names' do
      # EVSS requires us to pass the HTTP headers as lowercase
      expect(subject.to_h.find { |k, _| k.match(/^[[:upper:]]/) }).to be nil
    end

    it 'includes the users birls id' do
      expect(subject.to_h['va_eauth_birlsfilenumber']).to eq current_user.birls_id
    end
  end

  context 'with an LoA1 user' do
    let(:current_user) { FactoryBot.build(:user, :loa1) }

    it 'has the right LoA' do
      expect(subject.to_h['va_eauth_assurancelevel']).to eq '1'
    end
  end
end
