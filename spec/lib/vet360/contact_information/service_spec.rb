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
          expect(response.transaction.id).to eq('0b6344e3-3348-419c-bad9-c1a634e3d621')
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

  describe '#put_address' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }
    context 'when successful' do
      xit 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_address_success', VCR::MATCH_EVERYTHING) do
          address.id = 1299
          address.address_line_1 = '1494 Martin Luther King Rd'
          response = subject.put_address(address)
          expect(response.transaction.id).to eq('6e1e4e54-e851-4f5e-a2bf-eec0b17738f1')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#put_telephone' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_telephone_success', VCR::MATCH_EVERYTHING) do
          telephone.id = 1299
          telephone.phone_number = '5551235'
          response = subject.put_telephone(telephone)
          expect(response.transaction.id).to eq('6e1e4e54-e851-4f5e-a2bf-eec0b17738f1')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#post_telephone' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id, id: nil) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_telephone_success', VCR::MATCH_EVERYTHING) do
          response = subject.post_telephone(telephone)
          expect(response).to be_ok
        end
      end
    end

    context 'when an ID is included' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_telephone_w_id_error', VCR::MATCH_EVERYTHING) do
          telephone.id = 42
          expect { subject.post_telephone(telephone) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_PHON124')
          end
        end
      end
    end
  end

  describe '#get_telephone_transaction_status' do
    let(:transaction) { Vet360::Models::Transaction.new(id: transaction_id) }

    context 'when successful' do
      let(:transaction_id) { 'a50193df-f4d5-4b6a-b53d-36fed2db1a15' }
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/telephone_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_telephone_transaction_status(transaction)
          expect(response).to be_ok
          expect(response.transaction).to be_a(Vet360::Models::Transaction)
          expect(response.transaction.id).to eq(transaction_id)
        end
      end
    end

    context 'when not successful' do
      let(:transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }
      it 'returns a status of 404' do
        VCR.use_cassette('vet360/contact_information/telephone_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect { subject.get_telephone_transaction_status(transaction) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(404)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end

  describe '#get_email_transaction_status' do
    let(:transaction) { Vet360::Models::Transaction.new(id: transaction_id) }

    context 'when successful' do
      let(:transaction_id) { '786efe0e-fd20-4da2-9019-0c00540dba4d' }

      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_email_transaction_status(transaction)
          expect(response).to be_ok
          expect(response.transaction).to be_a(Vet360::Models::Transaction)
          expect(response.transaction.id).to eq(transaction_id)
        end
      end
    end

    context 'when not successful' do
      let(:transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }

      it 'returns a status of 404' do
        VCR.use_cassette('vet360/contact_information/email_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect { subject.get_email_transaction_status(transaction) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(404)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end

  describe '#get_address_transaction_status' do
    let(:transaction) { Vet360::Models::Transaction.new(id: transaction_id) }

    context 'when successful' do
      let(:transaction_id) { '0faf342f-5966-4d3f-8b10-5e9f911d07d2' }
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/address_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_address_transaction_status(transaction)
          expect(response).to be_ok
          expect(response.transaction).to be_a(Vet360::Models::Transaction)
          expect(response.transaction.id).to eq(transaction_id)
        end
      end
    end

    context 'when not successful' do
      let(:transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }
      it 'returns a status of 404' do
        VCR.use_cassette('vet360/contact_information/address_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect { subject.get_address_transaction_status(transaction) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(404)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end
end
