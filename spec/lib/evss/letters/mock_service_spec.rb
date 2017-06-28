# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::MockService do
  describe '.find_by_user' do
    let(:root) { Rails.root }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    subject { EVSS::Letters::MockService.new(auth_headers) }

    before do
      allow(Rails.root).to receive(:join).and_call_original
      allow(Rails.root).to receive(:join)
        .with('config', 'evss', 'mock_letters_response.yml')
        .and_return(root.join('spec', 'support', 'evss', 'mock_letters_response.yml'))
    end

    describe 'get_letters' do
      context 'when the yaml is valid' do
        let(:user) { build(:loa3_user) }

        it 'returns a hash of the hard coded response' do
          response = subject.get_letters
          expect(response.letters.count).to eq(8)
        end
      end
      context 'when the yaml is invalid' do
        let(:user) { build(:loa3_user, ssn: '123456789') }

        it 'logs and re-raises an error' do
          expect(Rails.logger).to receive(:error).once.with(
            "User with ssn: #{user.ssn} does not have key :get_letters in config/mock_letters_response.yml"
          )
          expect { subject.get_letters }.to raise_error NoMethodError
        end
      end
      context 'when the user is missing' do
        let(:user) { build(:loa3_user, ssn: '123456780') }

        it 'loads the default' do
          response = subject.get_letters
          expect(response.letters.count).to eq(8)
        end
      end
    end

    describe 'get_letter_beneficiary' do
      context 'when the yaml is valid' do
        let(:user) { build(:loa3_user) }

        it 'returns a hash of the hard coded response' do
          response = subject.get_letter_beneficiary
          expect(response.military_service.count).to eq(2)
        end
      end
      context 'when the yaml is invalid' do
        let(:user) { build(:loa3_user, ssn: '123456789') }

        it 'logs and re-raises an error' do
          expect(Rails.logger).to receive(:error).once.with(
            "User with ssn: #{user.ssn} does not have key :get_letter_beneficiary in config/mock_letters_response.yml"
          )
          expect { subject.get_letter_beneficiary }.to raise_error NoMethodError
        end
      end
    end

    describe 'download_letter_by_type' do
      before do
        allow(Rails.root).to receive(:join)
          .with('config/evss/letter.pdf')
          .and_return(root.join('config', 'evss', 'letter.pdf.example'))
      end
      context 'when the yaml is valid' do
        let(:user) { build(:loa3_user) }

        it 'returns the pdf described in the yaml file' do
          response = subject.download_by_type('commissary')
          expect(response).to include('%PDF-1.4')
        end
      end
      context 'when the yaml is invalid' do
        let(:user) { build(:loa3_user, ssn: '123456789') }

        it 'logs and re-raises an error' do
          expect(Rails.logger).to receive(:error).once.with(
            "User with ssn: #{user.ssn} does not have key :download_letter_by_type in config/mock_letters_response.yml"
          )
          expect { subject.download_by_type('commissary') }.to raise_error NoMethodError
        end
      end
    end
  end
end
