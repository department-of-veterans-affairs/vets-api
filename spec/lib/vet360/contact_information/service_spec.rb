# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ContactInformation::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  before do
    allow(user).to receive(:vet360_id).and_return('1')
  end

  describe '#get_person' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/person', VCR::MATCH_EVERYTHING) do
          response = subject.get_person

          expect(response).to be_ok
          expect(response.person).to be_a(Vet360::Models::Person)
        end
      end
    end

    context 'when not successful' do
      it 'returns a status of 404' do
        VCR.use_cassette('vet360/contact_information/person_error', VCR::MATCH_EVERYTHING) do
          expect { subject.get_person }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(404)
            expect(e.errors.first.code).to eq('VET360_CORE103')
            expect(e.errors.first.title).to eq('Not Found')
          end
        end
      end
    end
  end

  describe '#post_email' do
    let(:email) { build(:email) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_email_success') do # @TODO match on body!
          response = subject.post_email(email)
          expect(response).to be_ok
        end
      end
    end

    context 'when a duplicate exists' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_email_duplicate_error') do # @TODO match on body!
          expect do
            subject.post_email(email)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end

      it 'the exception matches what we expect' do
        VCR.use_cassette('vet360/contact_information/post_email_duplicate_error') do # @TODO match on body!
          begin
            subject.post_email(email)
          rescue Common::Exceptions::BackendServiceException => e
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_EMAIL301')
            expect(e.errors.first.title).to eq('Email Address Already Exists')
          end
        end
      end
    end
  end

  describe '#put_email' do
    let(:email) { build(:email) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_email_success') do # @TODO match on body!
          response = subject.put_email(email)
          expect(response).to be_ok
        end
      end
    end
  end
end
