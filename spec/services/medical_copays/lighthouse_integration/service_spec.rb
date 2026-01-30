# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::LighthouseIntegration::Service do
  describe 'StatsD metrics' do
    let(:service) { described_class.new('123') }

    describe '#list' do
      let(:raw_invoices) do
        {
          'entry' => [
            {
              'resource' => {
                'id' => 'invoice-1',
                'issuer' => { 'reference' => 'Organization/org-123' }
              }
            }
          ],
          'link' => [],
          'total' => 1
        }
      end
      let(:mock_bundle) { instance_double(Lighthouse::HCC::Bundle) }

      context 'on success' do
        before do
          allow(service).to receive_messages(
            invoice_service: double(list: raw_invoices),
            retrieve_organization_address: {
              city: 'Tampa',
              address_line1: '123 Test St',
              address_line2: nil,
              address_line3: nil,
              state: 'FL',
              postalCode: '33601'
            }
          )
          allow(Lighthouse::HCC::Invoice).to receive(:new).and_return(double)
          allow(Lighthouse::HCC::Bundle).to receive(:new).and_return(mock_bundle)
        end

        it 'increments initiated metric' do
          expect { service.list(count: 10, page: 1) }
            .to trigger_statsd_increment('api.mcp.lighthouse.list.initiated')
        end

        it 'increments success metric' do
          expect { service.list(count: 10, page: 1) }
            .to trigger_statsd_increment('api.mcp.lighthouse.list.success')
        end

        it 'measures latency' do
          expect { service.list(count: 10, page: 1) }
            .to trigger_statsd_measure('api.mcp.lighthouse.list.latency')
        end
      end

      context 'on failure' do
        before do
          allow(service).to receive(:invoice_service).and_raise(StandardError.new('API error'))
        end

        it 'increments initiated metric' do
          expect do
            service.list(count: 10, page: 1)
          rescue
            nil
          end
            .to trigger_statsd_increment('api.mcp.lighthouse.list.initiated')
        end

        it 'increments failure metric' do
          expect do
            service.list(count: 10, page: 1)
          rescue
            nil
          end
            .to trigger_statsd_increment('api.mcp.lighthouse.list.failure')
        end

        it 'does not increment success metric' do
          expect(StatsD).not_to receive(:increment).with('api.mcp.lighthouse.list.success')
          begin
            service.list(count: 10, page: 1)
          rescue
            nil
          end
        end
      end
    end

    describe '#get_detail' do
      let(:invoice_data) { { 'id' => 'invoice-1', 'account' => { 'reference' => 'Account/acc-1' } } }
      let(:mock_detail) { instance_double(Lighthouse::HCC::CopayDetail) }
      let(:base_stubs) do
        {
          invoice_service: double(read: invoice_data),
          fetch_invoice_dependencies: { account: {}, charge_items: {}, payments: [] },
          fetch_charge_item_dependencies: { encounters: {}, medication_dispenses: {} },
          fetch_medications: {}
        }
      end

      context 'on success' do
        before do
          allow(service).to receive_messages(base_stubs)
          allow(service).to receive_messages(
            fetch_organization_address: {
              address_line1: '123 Test St',
              address_line2: nil,
              address_line3: nil,
              city: 'Tampa',
              state: 'FL',
              postalCode: '33601'
            }
          )
          allow(Lighthouse::HCC::CopayDetail).to receive(:new).and_return(mock_detail)
        end

        it 'increments initiated metric' do
          expect { service.get_detail(id: 'invoice-1') }
            .to trigger_statsd_increment('api.mcp.lighthouse.detail.initiated')
        end

        it 'increments success metric' do
          expect { service.get_detail(id: 'invoice-1') }
            .to trigger_statsd_increment('api.mcp.lighthouse.detail.success')
        end

        it 'measures latency' do
          expect { service.get_detail(id: 'invoice-1') }
            .to trigger_statsd_measure('api.mcp.lighthouse.detail.latency')
        end
      end

      context 'when organization address is missing' do
        before do
          allow(service).to receive_messages(base_stubs)
          allow(service).to receive(:fetch_organization_address).and_return(nil)
        end

        it 'still builds a CopayDetail with nil facility_address' do
          expect(Lighthouse::HCC::CopayDetail).to receive(:new).with(
            hash_including(facility_address: nil)
          ).and_return(mock_detail)
          service.get_detail(id: 'invoice-1')
        end
      end

      context 'on failure' do
        before do
          allow(service).to receive(:invoice_service).and_raise(StandardError.new('API error'))
        end

        it 'increments initiated metric' do
          expect do
            service.get_detail(id: 'invoice-1')
          rescue
            nil
          end
            .to trigger_statsd_increment('api.mcp.lighthouse.detail.initiated')
        end

        it 'increments failure metric' do
          expect do
            service.get_detail(id: 'invoice-1')
          rescue
            nil
          end
            .to trigger_statsd_increment('api.mcp.lighthouse.detail.failure')
        end

        it 'does not increment success metric' do
          expect(StatsD).not_to receive(:increment).with('api.mcp.lighthouse.detail.success')
          begin
            service.get_detail(id: 'invoice-1')
          rescue
            nil
          end
        end
      end
    end
  end

  describe '#list' do
    it 'returns a list of invoices' do
      skip 'Temporarily skip flaky test'
      VCR.use_cassette('lighthouse/hcc/invoice_list_success') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        response = service.list(count: 10, page: 1)

        expect(response.total).to eq(10)
        expect(response.entries.first.class).to eq(Lighthouse::HCC::Invoice)
        expect(response.links.keys).to eq(%i[self first last])
        expect(response.page).to eq(1)
        expect(response.meta).to eq(
          {
            total: 10,
            page: 1,
            per_page: 50,
            copay_summary: {
              total_current_balance: 757.27,
              copay_bill_count: 10,
              last_updated_on: '2025-08-29T00:00:00Z'
            }
          }
        )
      end
    end

    it 'handles no records' do
      skip 'Temporarily skip flaky test'
      VCR.use_cassette('lighthouse/hcc/no_records') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        response = service.list(count: 10, page: 1)

        expect(response.entries).to be_empty
        expect(response.page).to be_zero
        expect(response.meta).to eq(
          {
            total: 0, page: 0, per_page: 10,
            copay_summary: {
              total_current_balance: 0.0,
              copay_bill_count: 0,
              last_updated_on: nil
            }
          }
        )
      end
    end

    context 'Errors' do
      let(:service) { MedicalCopays::LighthouseIntegration::Service.new('123') }
      let(:raw_invoices) do
        { 'entry' => [{ 'resource' => { 'issuer' => { 'reference' => 'Organization/4-O3d8XK44ejMS' } } }] }
      end

      it 'raises BadRequest for a 400 from Lighthouse' do
        skip 'Temporarily skip flaky test'
        VCR.use_cassette('lighthouse/hcc/auth_error') do
          allow(Auth::ClientCredentials::JWTGenerator)
            .to receive(:generate_token).and_return('fake-jwt')

          expect do
            service.list(count: 10, page: 1)
          end.to raise_error(Common::Exceptions::BadRequest)
        end
      end

      it 'raises MissingOrganizationIdError' do
        skip 'Temporarily skip flaky test'
        raw_invoices['entry'].first['resource']['issuer']['reference'] = nil

        allow(service).to receive(:invoice_service).and_return(double(list: raw_invoices))

        expect { service.list(count: 10, page: 1) }
          .to raise_error(
            MedicalCopays::LighthouseIntegration::Service::MissingOrganizationIdError,
            'Missing org_id for invoice entry'
          )
      end

      it 'raises MissingCityError' do
        skip 'Temporarily skip flaky test'
        allow(service).to receive(:invoice_service).and_return(double(list: raw_invoices))

        allow(service).to receive(:retrieve_organization_address).with('4-O3d8XK44ejMS').and_return(nil)

        expect { service.list(count: 10, page: 1) }
          .to raise_error(
            MedicalCopays::LighthouseIntegration::Service::MissingCityError,
            'Missing city for org_id 4-O3d8XK44ejMS'
          )
      end
    end
  end

  describe '#get_detail' do
    it 'returns copay detail with populated attributes' do
      VCR.use_cassette('lighthouse/hcc/copay_detail_success') do
        allow(Auth::ClientCredentials::JWTGenerator)
          .to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('32000551')
        result = service.get_detail(id: '4-1abZUKu7LnbcQc')

        expect(result).to be_a(Lighthouse::HCC::CopayDetail)
        expect(result.external_id).to be_present
        expect(result.facility).to be_present
        expect(result.facility).to be_a(Hash)
        expect(result.facility['name']).to be_present
        expect(result.facility['address']).to be_a(Hash)

        address = result.facility['address']
        expect(address['address_line1']).to eq('3000 CORAL HILLS DR')
        expect(address['city']).to eq('CORAL SPRINGS')
        expect(address['state']).to eq('FL')
        expect(address['postalCode']).to eq('330654108')

        expect(result.status).to be_present
        expect(result.line_items).to be_an(Array)
        expect(result.payments).to be_an(Array)
      end
    end

    it 'raises BadRequest for a 400 from Lighthouse' do
      VCR.use_cassette('lighthouse/hcc/auth_error') do
        allow(Auth::ClientCredentials::JWTGenerator)
          .to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('32000551')

        expect do
          service.get_detail(id: '4-1abZUKu7LnbcQc')
        end.to raise_error(Common::Exceptions::BadRequest)
      end
    end
  end
end
