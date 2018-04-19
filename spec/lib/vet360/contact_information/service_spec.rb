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
    let(:email) { build(:email, vet360_id: user.vet360_id) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_email_success', VCR::MATCH_EVERYTHING) do
          email.id = nil
          email.email_address = 'person42@example.com'
          response = subject.post_email(email)
          expect(response).to be_ok
        end
      end
    end

    context 'when a duplicate exists' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_email_duplicate_error', VCR::MATCH_EVERYTHING) do
          email.id = nil
          email.email_address = 'person42@example.com'
          expect { subject.post_email(email) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_EMAIL301')
            expect(e.errors.first.title).to eq('Email Address Already Exists')
          end
        end
      end
    end

    context 'when an ID is included' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_email_w_id_error', VCR::MATCH_EVERYTHING) do
          email.id = 42
          email.email_address = 'person42@example.com'
          expect { subject.post_email(email) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_EMAIL200')
          end
        end
      end
    end
  end

  describe '#put_email' do
    let(:email) { build(:email, vet360_id: user.vet360_id) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_email_success', VCR::MATCH_EVERYTHING) do
          email.id = 42
          email.email_address = 'person42@example.com'
          response = subject.put_email(email)
          expect(response.transaction.id).to eq('7f441880-173f-4deb-aa8b-c26b794eb3e1')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#post_address' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_address_success', VCR::MATCH_EVERYTHING) do
          address.id = nil
          response = subject.post_address(address)
          expect(response).to be_ok
        end
      end
    end

    context 'when an ID is included' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_address_w_id_error', VCR::MATCH_EVERYTHING) do
          address.id = 42
          expect { subject.post_address(address) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_ADDR200')
          end
        end
      end
    end
  end
end
