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

  describe '#to_h' do
    let(:current_user) { FactoryBot.build(:user, :loa3) }

    before do
      allow(current_user).to receive(:ssn).and_return(nil)
      allow(current_user).to receive(:edipi).and_return(nil)
    end

    let(:headers) { subject.to_h }

    it 'will not return nil header values' do
      expect(headers.values.include?(nil)).to eq false
    end

    it 'sets any nil headers values to an empty string', :aggregate_failures do
      expect(headers['va_eauth_dodedipnid']).to eq ''
      expect(headers['va_eauth_pnid']).to eq ''
    end

    it 'does not modify non-nil header values', :aggregate_failures do
      expect(headers['va_eauth_firstName']).to eq current_user.first_name
      expect(headers['va_eauth_lastName']).to eq current_user.last_name
    end
  end
end
