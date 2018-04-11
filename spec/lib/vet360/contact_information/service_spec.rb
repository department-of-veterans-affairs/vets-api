# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ContactInformation::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  before do
    allow(user).to receive(:vet360_id).and_return('123456')
  end

  xdescribe '#get_person' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/person', { match_requests_on: %i[headers] }) do
          response = subject.get_person
byebug
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#post_email' do

    let(:email) { build(:email) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_email_success') do #@TODO match on body!
          response = subject.post_email(email)
          expect(response).to be_ok
        end
      end
    end

    context 'when a duplicate exists' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_email_duplicate_error') do #@TODO match on body!
          response = nil
          expect {
            response = subject.post_email(email)
          }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end

      it 'has a status code 400' do
        VCR.use_cassette('vet360/contact_information/post_email_duplicate_error') do #@TODO match on body!
            begin
              response = subject.post_email(email) 
            rescue
              expect(response.metadata[:status]).to equal(400)
            end
            # byebug
            
        end
      end

    end

  end

  describe '#put_email' do

    let(:email) { build(:email) }
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_email_success') do #@TODO match on body!
          response = subject.put_email(email)
          expect(response).to be_ok
        end
      end
    end
  end

end
