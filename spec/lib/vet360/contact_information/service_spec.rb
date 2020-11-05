# frozen_string_literal: true

require 'rails_helper'
require 'vet360/contact_information/service'

describe Vet360::ContactInformation::Service, skip_vet360: true do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:vet360_id) { '1' }

  before do
    allow(user).to receive(:vet360_id).and_return(vet360_id)
    allow(user).to receive(:icn).and_return('1234')
  end

  describe '#get_person' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/person_full', VCR::MATCH_EVERYTHING) do
          response = subject.get_person
          expect(response).to be_ok
          expect(response.person).to be_a(Vet360::Models::Person)
        end
      end

      it 'supports international provinces' do
        VCR.use_cassette('vet360/contact_information/person_intl_addr', VCR::MATCH_EVERYTHING) do
          response = subject.get_person

          expect(response.person.addresses[0].province).to eq('province')
        end
      end
    end

    context 'when not successful' do
      let(:vet360_id) { '6767671' }

      it 'returns a status of 404' do
        VCR.use_cassette('vet360/contact_information/person_error', VCR::MATCH_EVERYTHING) do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { vet360_id: user.vet360_id },
            { vet360: :person_not_found },
            :warning
          )

          response = subject.get_person
          expect(response).not_to be_ok
          expect(response.person).to be_nil
        end
      end
    end

    context 'when service returns a 503 error code' do
      it 'raises a BackendServiceException error' do
        VCR.use_cassette('vet360/contact_information/person_status_503', VCR::MATCH_EVERYTHING) do
          expect { subject.get_person }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(502)
            expect(e.errors.first.code).to eq('VET360_502')
          end
        end
      end
    end
  end

  describe '#post_email' do
    let(:email) { build(:email, vet360_id: user.vet360_id, source_system_user: user.icn) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_email_success', VCR::MATCH_EVERYTHING) do
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
    let(:email) { build(:email, vet360_id: user.vet360_id, source_system_user: user.icn) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_email_success', VCR::MATCH_EVERYTHING) do
          email.id = 8087
          email.email_address = 'person42@example.com'
          response = subject.put_email(email)
          expect(response.transaction.id).to eq('7d1667a5-df5f-4559-be35-b36042c61187')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#post_address' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id, source_system_user: user.icn) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_address_success', VCR::MATCH_EVERYTHING) do
          address.id = nil
          address.address_line1 = '1493 Martin Luther King Rd'
          address.city = 'Fulton'
          address.state_code = 'MS'
          address.zip_code = '38843'
          response = subject.post_address(address)
          expect(response).to be_ok
        end
      end
    end

    context 'when an ID is included' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_address_w_id_error', VCR::MATCH_EVERYTHING) do
          address.id = 42
          address.address_line1 = '1493 Martin Luther King Rd'
          address.city = 'Fulton'
          address.state_code = 'MS'
          address.zip_code = '38843'
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
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id, source_system_user: user.icn) }

    context 'with a validation key' do
      let(:address) do
        build(:vet360_address, :override, country_name: nil)
      end

      it 'will override the address error', run_at: '2020-02-14T00:19:15.000Z' do
        VCR.use_cassette(
          'vet360/contact_information/put_address_override',
          VCR::MATCH_EVERYTHING
        ) do
          response = subject.put_address(address)
          expect(response.status).to eq(200)
          expect(response.transaction.id).to eq('7f01230f-56e3-4289-97ed-6168d2d23722')
        end
      end
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_address_success', VCR::MATCH_EVERYTHING) do
          address.id = 15_035
          address.address_line1 = '1494 Martin Luther King Rd'
          address.city = 'Fulton'
          address.state_code = 'MS'
          address.zip_code = '38843'
          response = subject.put_address(address)
          expect(response.transaction.id).to eq('63e7792c-887e-4d57-b6ed-801edcae2c2d')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#put_telephone' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id, source_system_user: user.icn) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_telephone_success', VCR::MATCH_EVERYTHING) do
          telephone.id = 17_259
          telephone.phone_number = '5551235'
          response = subject.put_telephone(telephone)
          expect(response.transaction.id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#post_telephone' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id, id: nil, source_system_user: user.icn) }

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

  describe '#put_permission' do
    let(:permission) { build(:permission, vet360_id: '1411684', source_system_user: user.icn) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/put_permission_success', VCR::MATCH_EVERYTHING) do
          permission.id = 401
          permission.permission_value = true
          response = subject.put_permission(permission)
          expect(response.transaction.id).to eq('98358039-5f4d-4ada-9a43-d385ce1cb275')
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#post_permission' do
    let(:permission) { build(:permission, vet360_id: '1411684', id: nil, source_system_user: user.icn) }

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/post_permission_success', VCR::MATCH_EVERYTHING) do
          response = subject.post_permission(permission)
          expect(response).to be_ok
        end
      end
    end

    context 'when an ID is included' do
      it 'raises an exception' do
        VCR.use_cassette('vet360/contact_information/post_permission_w_id_error', VCR::MATCH_EVERYTHING) do
          permission.id = 401
          expect { subject.post_permission(permission) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(502)
            expect(e.errors.first.code).to eq('VET360_502')
          end
        end
      end
    end
  end

  describe '#get_telephone_transaction_status' do
    context 'when successful' do
      let(:transaction_id) { 'a2af8cd1-472c-4e6f-bd5a-f95e31e351b7' }

      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/telephone_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_telephone_transaction_status(transaction_id)
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
          expect { subject.get_telephone_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end

  describe '#get_email_transaction_status' do
    context 'when successful' do
      let(:transaction_id) { 'cb99a754-9fa9-4f3c-be93-ede12c14b68e' }

      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_email_transaction_status(transaction_id)
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
          expect { subject.get_email_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end

      it 'includes "general_client_error" tag in sentry error', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/email_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect(Raven).to receive(:tags_context).with(vet360: 'general_client_error')

          expect { subject.get_email_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end

  describe '#get_address_transaction_status' do
    context 'when successful' do
      let(:transaction_id) { 'a030185b-e88b-4e0d-a043-93e4f34c60d6' }

      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/address_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_address_transaction_status(transaction_id)
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
          expect { subject.get_address_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end

      it 'logs the failure to pii logs' do
        allow(user).to receive(:vet360_id).and_return('1133902')

        VCR.use_cassette(
          'vet360/contact_information/address_transaction_addr_not_found',
          VCR::MATCH_EVERYTHING
        ) do
          subject.get_address_transaction_status('d8cd4a73-6241-46fe-95a4-e0776f8f6f64')

          personal_information_log = PersonalInformationLog.last

          expect(personal_information_log.error_class).to eq(
            'Vet360::ContactInformation::AddressTransactionResponseError'
          )
          expect(personal_information_log.data).to eq(
            'errors' => [
              { 'key' => 'addressBio.AddressCouldNotBeFound',
                'code' => 'ADDRVAL112',
                'text' => 'The Address could not be found',
                'severity' => 'ERROR' }
            ],
            'address' =>
             { 'county' => {},
               'city_name' => 'Springfield',
               'zip_code5' => '22150',
               'state_code' => 'VA',
               'address_pou' => 'CORRESPONDENCE',
               'source_date' => '2019-10-21T18:32:31Z',
               'address_type' => 'DOMESTIC',
               'country_name' => 'United States',
               'address_line1' => 'hgjghjghj' }
          )
        end
      end
    end
  end

  describe '#get_permission_transaction_status' do
    context 'when successful' do
      let(:transaction_id) { 'b1b06a34-c6a8-412e-82e7-df09d84862f3' }

      it 'returns a status of 200' do
        VCR.use_cassette('vet360/contact_information/permission_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_permission_transaction_status(transaction_id)
          expect(response).to be_ok
          expect(response.transaction).to be_a(Vet360::Models::Transaction)
          expect(response.transaction.id).to eq(transaction_id)
        end
      end
    end

    context 'when not successful' do
      let(:transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }

      it 'returns a status of 400' do
        VCR.use_cassette('vet360/contact_information/permission_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect { subject.get_permission_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end

  context 'When a user does not have a vet360_id' do
    let(:error_message) { 'User does not have a vet360_id' }

    before do
      allow(user).to receive(:vet360_id).and_return(nil)
    end

    context 'when calling #get_person' do
      it 'raises an error', :aggregate_failures do
        expect { subject.get_person }.to raise_error do |e|
          expect(e).to be_a(RuntimeError)
          expect(e.message).to eq(error_message)
        end
      end
    end

    context 'when using the underlying #post_or_put_data' do
      it 'raises an error', :aggregate_failures do
        email = build(:email)

        expect { subject.post_email(email) }.to raise_error do |e|
          expect(e).to be_a(RuntimeError)
          expect(e.message).to eq(error_message)
        end
      end
    end

    context 'when using the underlying #get_transaction_status' do
      it 'raises an error', :aggregate_failures do
        expect { subject.get_address_transaction_status('1234') }.to raise_error do |e|
          expect(e).to be_a(RuntimeError)
          expect(e.message).to eq(error_message)
        end
      end
    end
  end

  describe '#get_person_transaction_status' do
    context 'when successful' do
      let(:transaction_id) { '786efe0e-fd20-4da2-9019-0c00540dba4d' }

      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/person_transaction_status', VCR::MATCH_EVERYTHING) do
          response = subject.get_person_transaction_status(transaction_id)

          expect(response).to be_ok
          expect(response.transaction).to be_a(Vet360::Models::Transaction)
          expect(response.transaction.id).to eq(transaction_id)
        end
      end
    end

    context 'when not successful' do
      let(:transaction_id) { 'd47b3d96-9ddd-42be-ac57-8e564aa38029' }

      it 'returns a status of 400', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/person_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect { subject.get_person_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end

      it 'logs a vet360 tagged error message to sentry', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/person_transaction_status_error', VCR::MATCH_EVERYTHING) do
          expect(Raven).to receive(:tags_context).with(vet360: 'failed_vet360_id_initializations')

          expect { subject.get_person_transaction_status(transaction_id) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(400)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end
  end

  context 'When reporting StatsD statistics' do
    context 'when checking transaction status' do
      context 'for emails' do
        it 'increments the StatsD Vet360 posts_and_puts counters' do
          transaction_id = 'cb99a754-9fa9-4f3c-be93-ede12c14b68e'

          VCR.use_cassette('vet360/contact_information/email_transaction_status') do
            expect { subject.get_email_transaction_status(transaction_id) }.to trigger_statsd_increment(
              "#{Vet360::Service::STATSD_KEY_PREFIX}.posts_and_puts.success"
            )
          end
        end
      end

      context 'for telephones' do
        it 'increments the StatsD Vet360 posts_and_puts counters' do
          transaction_id = 'a2af8cd1-472c-4e6f-bd5a-f95e31e351b7'

          VCR.use_cassette('vet360/contact_information/telephone_transaction_status') do
            expect { subject.get_telephone_transaction_status(transaction_id) }.to trigger_statsd_increment(
              "#{Vet360::Service::STATSD_KEY_PREFIX}.posts_and_puts.success"
            )
          end
        end
      end

      context 'for addresses' do
        it 'increments the StatsD Vet360 posts_and_puts counters' do
          transaction_id = 'a030185b-e88b-4e0d-a043-93e4f34c60d6'

          VCR.use_cassette('vet360/contact_information/address_transaction_status') do
            expect { subject.get_address_transaction_status(transaction_id) }.to trigger_statsd_increment(
              "#{Vet360::Service::STATSD_KEY_PREFIX}.posts_and_puts.success"
            )
          end
        end
      end

      context 'for initializing a vet360_id' do
        it 'increments the StatsD Vet360 init_vet360_id counters' do
          transaction_id = '786efe0e-fd20-4da2-9019-0c00540dba4d'

          VCR.use_cassette('vet360/contact_information/person_transaction_status') do
            expect { subject.get_person_transaction_status(transaction_id) }.to trigger_statsd_increment(
              "#{Vet360::Service::STATSD_KEY_PREFIX}.init_vet360_id.success"
            )
          end
        end
      end
    end
  end
end
