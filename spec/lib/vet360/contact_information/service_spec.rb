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

  describe '#get_email_transaction_status' do
    context 'when successful' do
      let(:transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }
      let(:transaction) { Vet360::Models::Transaction.new(id: transaction_id) }

      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_email_transaction_status(transaction)
          expect(response).to be_ok
        end
      end
    end
  end
end
