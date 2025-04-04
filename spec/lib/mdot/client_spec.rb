# frozen_string_literal: true

require 'rails_helper'
require 'mdot/client'

describe MDOT::Client, type: :mdot_helpers do
  subject { described_class.new(user) }

  let(:user_details) do
    {
      first_name: 'Greg',
      last_name: 'Anderson',
      middle_name: 'A',
      birth_date: '19910405',
      ssn: '000550237'
    }
  end

  let(:user) { build(:user, :loa3, user_details) }

  describe '#get_supplies' do
    context 'with a valid supplies response' do
      it 'returns an array of supplies' do
        VCR.use_cassette(
          'mdot/get_supplies_200',
          match_requests_on: %i[method uri headers],
          erb: { icn: user.icn }
        ) do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
        end
      end
    end

    context 'with a supplies response that includes assistive devices' do
      it 'returns an array of supplies' do
        VCR.use_cassette(
          'mdot/get_supplies_assistive_devices_200',
          match_requests_on: %i[method uri headers],
          erb: { icn: user.icn }
        ) do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
          expect(response.eligibility.attributes[:assistive_devices]).to be(true)
        end
      end
    end

    context 'with an unknown DLC service error' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('mdot/get_supplies_502') do
          expect(StatsD).to receive(:increment).once.with(
            'api.external_http_request.MDOT.failed', 1, { tags: ['endpoint:/supplies', 'method:get'] }
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:502'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.total'
          )
          expect { subject.get_supplies }.to raise_error(
            MDOT::Exceptions::ServiceException
          ) do |e|
            expect(e.message).to match(/MDOT_502/)
          end
        end
      end
    end

    context 'when the DLC API is unavailable' do
      it 'raises a 503' do
        VCR.use_cassette('mdot/get_supplies_503') do
          expect(StatsD).to receive(:increment).once.with(
            'api.external_http_request.MDOT.failed', 1, { tags: ['endpoint:/supplies', 'method:get'] }
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:503'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.total'
          )
          expect { subject.get_supplies }.to raise_error(
            MDOT::Exceptions::ServiceException
          ) do |e|
            expect(e.message).to match(/MDOT_service_unavailable/)
          end
        end
      end
    end

    context 'with a deceased veteran' do
      it 'returns a 403' do
        VCR.use_cassette('mdot/get_supplies_403') do
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:403'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.total'
          )
          expect { subject.get_supplies }.to raise_error(
            MDOT::Exceptions::ServiceException
          ) do |e|
            expect(e.message).to match(/MDOT_deceased/)
          end
        end
      end
    end

    context 'with a veteran not in dlc database' do
      it 'returns a 422' do
        VCR.use_cassette('mdot/get_supplies_422') do
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:422'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.get_supplies.total'
          )
          expect { subject.get_supplies }.to raise_error(
            MDOT::Exceptions::ServiceException
          ) do |e|
            expect(e.message).to match(/MDOT_invalid/)
          end
        end
      end
    end

    context 'validates temporary OR permanent address' do
      before do
        VCR.insert_cassette(
          cassette,
          match_requests_on: %i[method uri headers],
          erb: { icn: user.icn }
        )
      end

      after { VCR.eject_cassette }

      context 'with a null temporary_address value from system of record' do
        let!(:cassette) { 'mdot/get_supplies_null_temp_address_200' }

        it 'returns a valid response' do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
        end
      end

      context 'with a no temporary_address from system of record' do
        let(:cassette) { 'mdot/get_supplies_no_temp_address_200' }

        it 'returns a valid response' do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
        end
      end

      context 'with a null permanent_address value from system of record' do
        let(:cassette) { 'mdot/get_supplies_null_perm_address_200' }

        it 'returns a valid response' do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
        end
      end

      context 'with a no permanent_address from system of record' do
        let(:cassette) { 'mdot/get_supplies_no_perm_address_200' }

        it 'returns a valid response' do
          response = subject.get_supplies
          expect(response).to be_ok
          expect(response).to be_an MDOT::Response
        end
      end
    end
  end

  describe '#submit_order' do
    let(:valid_order) do
      {
        'useVeteranAddress' => true,
        'useTemporaryAddress' => false,
        'vetEmail' => 'vet1@va.gov',
        'order' => [{ 'productId' => 2499 }],
        'permanentAddress' => {
          'street' => '125 SOME RD',
          'street2' => 'APT 101',
          'city' => 'DENVER',
          'state' => 'CO',
          'country' => 'United States',
          'postalCode' => '111119999'
        },
        'temporaryAddress' => {
          'street' => '17250 w colfax ave',
          'street2' => 'a-204',
          'city' => 'Golden',
          'state' => 'CO',
          'country' => 'United States',
          'postalCode' => '80401'
        }
      }
    end

    let(:invalid_order) do
      {
        'useVeteranAddress' => true,
        'useTemporaryAddress' => false,
        'vetEmail' => 'vet1@va.gov',
        'order' => [],
        'permanentAddress' => {
          'street' => '125 SOME RD',
          'street2' => 'APT 101',
          'city' => 'DENVER',
          'state' => 'CO',
          'country' => 'United States',
          'postalCode' => '111119999'
        },
        'temporaryAddress' => {
          'street' => '17250 w colfax ave',
          'street2' => 'a-204',
          'city' => 'Golden',
          'state' => 'CO',
          'country' => 'United States',
          'postalCode' => '80401'
        }
      }
    end

    let(:missing_order) do
      {
        'useVeteranAddress' => true,
        'useTemporaryAddress' => false,
        'vetEmail' => 'vet1@va.gov',
        'permanentAddress' => {
          'street' => '125 SOME RD',
          'street2' => 'APT 101',
          'city' => 'DENVER',
          'state' => 'CO',
          'country' => 'United States',
          'postalCode' => '111119999'
        },
        'temporaryAddress' => {
          'street' => '17250 w colfax ave',
          'street2' => 'a-204',
          'city' => 'Golden',
          'state' => 'CO',
          'country' => 'United States',
          'postalCode' => '80401'
        }
      }
    end

    context 'with a valid supplies order' do
      it 'returns a successful response' do
        VCR.use_cassette('mdot/submit_order', VCR::MATCH_EVERYTHING) do
          set_mdot_token_for(user)
          res = subject.submit_order(valid_order)
          expect(res[0]['status']).to eq('Order Processed')
          expect(res[0]['order_id']).to be_an(Integer)
        end
      end
    end

    context 'with an unknown DLC service error' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('mdot/submit_order_502') do
          expect(StatsD).to receive(:increment).once.with(
            'api.external_http_request.MDOT.failed', 1, { tags: ['endpoint:/supplies', 'method:post'] }
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.submit_order.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:502'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.submit_order.total'
          )
          set_mdot_token_for(user)
          expect { subject.submit_order(valid_order) }.to raise_error(MDOT::Exceptions::ServiceException)
        end
      end
    end

    context 'with an unknown DLC client error' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('mdot/submit_order_400') do
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.submit_order.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:400'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.submit_order.total'
          )
          set_mdot_token_for(user)
          expect { subject.submit_order(valid_order) }.to raise_error(MDOT::Exceptions::ServiceException)
        end
      end
    end

    context 'with an unknown DLC client error with missing body' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('mdot/submit_order_missing_body_400') do
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.submit_order.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:400'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.mdot.submit_order.total'
          )
          set_mdot_token_for(user)
          expect { subject.submit_order(valid_order) }.to raise_error(MDOT::Exceptions::ServiceException)
        end
      end
    end

    context 'with an malformed order' do
      it 'returns a 422 error' do
        set_mdot_token_for(user)
        expect { subject.submit_order(invalid_order) }.to raise_error(
          MDOT::Exceptions::ServiceException
        ) do |e|
          expect(e.message).to match(/MDOT_supplies_not_selected/)
        end
      end
    end

    context 'with a missing order property' do
      it 'returns a 422 error' do
        set_mdot_token_for(user)
        expect { subject.submit_order(missing_order) }.to raise_error(
          MDOT::Exceptions::ServiceException
        ) do |e|
          expect(e.message).to match(/MDOT_supplies_not_selected/)
        end
      end
    end
  end
end
