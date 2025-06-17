# frozen_string_literal: true

require 'rails_helper'
require 'evss/pciu/service'

describe EVSS::PCIU::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  describe '#get_email_address' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/email') do
          response = subject.get_email_address

          expect(response).to be_ok
        end
      end

      it 'returns a users email address value and effective_date' do
        VCR.use_cassette('evss/pciu/email') do
          response = subject.get_email_address
          expect(response.attributes.deep_symbolize_keys).to include :effective_at, :email
        end
      end
    end
  end

  describe '#get_primary_phone' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/primary_phone') do
          response = subject.get_primary_phone

          expect(response).to be_ok
        end
      end

      it 'returns a users primary phone number, extension and country code' do
        VCR.use_cassette('evss/pciu/primary_phone') do
          response = subject.get_primary_phone
          expect(response.attributes.deep_symbolize_keys).to include :country_code, :number, :extension
        end
      end
    end
  end

  describe '#get_alternate_phone' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/alternate_phone') do
          response = subject.get_alternate_phone

          expect(response).to be_ok
        end
      end

      it 'returns a users alternate phone number, extension and country code' do
        VCR.use_cassette('evss/pciu/alternate_phone') do
          response = subject.get_alternate_phone

          expect(response.attributes.deep_symbolize_keys).to include :country_code, :number, :extension
        end
      end
    end
  end

  describe '#post_primary_phone' do
    let(:phone) { build(:phone_number, :nil_effective_date) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/post_primary_phone') do
          response = subject.post_primary_phone(phone)

          expect(response).to be_ok
        end
      end

      it 'POSTs and returns a users primary phone number, extension and country code' do
        VCR.use_cassette('evss/pciu/post_primary_phone') do
          response = subject.post_primary_phone(phone)

          expect(response.attributes.deep_symbolize_keys).to include :country_code, :number, :extension
        end
      end
    end

    context 'with a 500 response' do
      it 'raises a Common::Exceptions::BackendServiceException error' do
        VCR.use_cassette('evss/pciu/post_primary_phone_status_500') do
          expect { subject.post_primary_phone(phone) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'raises a Common::Exceptions::Forbidden error' do
        VCR.use_cassette('evss/pciu/post_primary_phone_status_403') do
          expect { subject.post_primary_phone(phone) }.to raise_error(
            Common::Exceptions::Forbidden
          )
        end
      end
    end

    context 'with a 400 response' do
      it 'raises a Common::Exceptions::BackendServiceException error' do
        VCR.use_cassette('evss/pciu/post_primary_phone_status_400') do
          expect { subject.post_primary_phone(phone) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#post_alternate_phone' do
    let(:phone) { build(:phone_number, :nil_effective_date) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/post_alternate_phone') do
          response = subject.post_alternate_phone(phone)

          expect(response).to be_ok
        end
      end

      it 'POSTs and returns a users alternate phone number, extension and country code' do
        VCR.use_cassette('evss/pciu/post_alternate_phone') do
          response = subject.post_alternate_phone(phone)

          expect(response.attributes.deep_symbolize_keys).to include :country_code, :number, :extension
        end
      end
    end

    context 'with a 500 response' do
      it 'raises a Common::Exceptions::BackendServiceException error' do
        VCR.use_cassette('evss/pciu/post_alternate_phone_status_500') do
          expect { subject.post_alternate_phone(phone) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'raises a Common::Exceptions::Forbidden error' do
        VCR.use_cassette('evss/pciu/post_alternate_phone_status_403') do
          expect { subject.post_alternate_phone(phone) }.to raise_error(
            Common::Exceptions::Forbidden
          )
        end
      end
    end

    context 'with a 400 response' do
      it 'raises a Common::Exceptions::BackendServiceException error' do
        VCR.use_cassette('evss/pciu/post_alternate_phone_status_400') do
          expect { subject.post_alternate_phone(phone) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#post_email_address' do
    let(:email_address) { build(:email_address) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/post_email_address') do
          response = subject.post_email_address(email_address)

          expect(response).to be_ok
        end
      end

      it 'POSTs and returns a users email address and effective_date' do
        VCR.use_cassette('evss/pciu/post_email_address') do
          response = subject.post_email_address(email_address)

          expect(response.attributes.deep_symbolize_keys).to include :effective_at, :email
        end
      end
    end

    context 'with a 500 response' do
      it 'raises a Common::Exceptions::BackendServiceException error' do
        VCR.use_cassette('evss/pciu/post_email_address_status_500') do
          expect { subject.post_email_address(email_address) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'raises a Common::Exceptions::Forbidden error' do
        VCR.use_cassette('evss/pciu/post_email_address_status_403') do
          expect { subject.post_email_address(email_address) }.to raise_error(
            Common::Exceptions::Forbidden
          )
        end
      end
    end

    context 'with a 400 response' do
      it 'raises a Common::Exceptions::BackendServiceException error' do
        VCR.use_cassette('evss/pciu/post_email_address_status_400') do
          expect { subject.post_email_address(email_address) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
