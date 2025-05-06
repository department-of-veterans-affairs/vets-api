# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::VSOReloader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  describe 'importer' do
    it 'reloads data from pulldown' do
      VCR.use_cassette('veteran/ogc_poa_data') do
        Veteran::VSOReloader.new.perform
        expect(Veteran::Service::Representative.count).to eq 435
        expect(Veteran::Service::Organization.count).to eq 3
        expect(Veteran::Service::Representative.attorneys.count).to eq 241
        expect(Veteran::Service::Representative.veteran_service_officers.count).to eq 152
        expect(Veteran::Service::Representative.claim_agents.count).to eq 42
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    it 'loads attorneys with the poa codes loaded' do
      VCR.use_cassette('veteran/ogc_attorney_data') do
        Veteran::VSOReloader.new.reload_attorneys
        expect(Veteran::Service::Representative.last.poa_codes).to include('9GB')
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    it 'loads a claim agent with the poa code' do
      VCR.use_cassette('veteran/ogc_claim_agent_data') do
        Veteran::VSOReloader.new.reload_claim_agents
        expect(Veteran::Service::Representative.last.poa_codes).to include('FDN')
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    it 'loads a vso rep with the poa code' do
      VCR.use_cassette('veteran/ogc_vso_rep_data') do
        Veteran::VSOReloader.new.reload_vso_reps
        expect(Veteran::Service::Representative.last.poa_codes).to include('095')
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    context 'existing organizations' do
      let(:org) do
        create(:organization, poa: '091', name: 'Testing', phone: '222-555-5555', state: 'ZZ', city: 'New York')
      end

      it 'only updates name, phone, and state' do
        VCR.use_cassette('veteran/ogc_vso_rep_data') do
          expect(org.name).to eq('Testing')
          expect(org.phone).to eq('222-555-5555')
          expect(org.state).to eq('ZZ')
          expect(org.city).to eq('New York')

          Veteran::VSOReloader.new.reload_vso_reps
          org.reload

          expect(org.name).to eq('African American PTSD Association')
          expect(org.phone).to eq('253-589-0766')
          expect(org.state).to eq('WA')
          expect(org.city).to eq('New York')
        end
      end
    end

    describe "storing a VSO's middle initial" do
      it 'stores the middle initial if it exists' do
        VCR.use_cassette('veteran/ogc_vso_rep_data') do
          Veteran::VSOReloader.new.reload_vso_reps

          veteran_rep = Veteran::Service::Representative.find_by!(first_name: 'Edgar', last_name: 'Anderson')
          expect(veteran_rep.middle_initial).to eq('B')
        end
      end

      it 'does not break if a middle initial does not exist' do
        VCR.use_cassette('veteran/ogc_vso_rep_data_no_middle_initial') do
          Veteran::VSOReloader.new.reload_vso_reps

          veteran_rep = Veteran::Service::Representative.find_by!(first_name: 'Edgar', last_name: 'Anderson')
          expect(veteran_rep.middle_initial).to eq('')
        end
      end
    end

    context 'leaving test users alone' do
      before do
        Veteran::Service::Representative.create(
          representative_id: '98765',
          first_name: 'Tamara',
          last_name: 'Ellis',
          email: 'va.api.user+idme.001@gmail.com',
          poa_codes: %w[067 A1Q 095 074 083 1NY]
        )

        Veteran::Service::Representative.create(
          representative_id: '12345',
          first_name: 'John',
          last_name: 'Doe',
          email: 'va.api.user+idme.007@gmail.com',
          poa_codes: %w[072 A1H 095 074 083 1NY]
        )
      end

      it 'does not destroy test users' do
        VCR.use_cassette('veteran/ogc_poa_data') do
          Veteran::VSOReloader.new.perform
          expect(Veteran::Service::Representative.where(first_name: 'Tamara', last_name: 'Ellis').count).to eq 1
          expect(Veteran::Service::Representative.where(first_name: 'John', last_name: 'Doe').count).to eq 1
        end
      end
    end

    context 'with a failed connection' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                               'some message')
      end

      it 'notifies slack' do
        expect_any_instance_of(SlackNotify::Client).to receive(:notify)
        Veteran::VSOReloader.new.perform
      end
    end

    context 'with a client error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
      end

      it 'notifies slack' do
        expect_any_instance_of(SlackNotify::Client).to receive(:notify)
        subject.new.perform
      end
    end

    context 'handling names' do
      before do
        VCR.use_cassette('veteran/ogc_vso_rep_data') do
          Veteran::VSOReloader.new.reload_vso_reps
        end
      end

      context 'with multiple first names' do
        it 'handles it correctly' do
          veteran_rep = Veteran::Service::Representative.find_by!(representative_id: '82390')
          expect(veteran_rep.first_name).to eq('Anna Mae')
          expect(veteran_rep.middle_initial).to eq('B')
        end
      end

      context 'invalid name' do
        it 'handles it correctly' do
          veteran_rep = Veteran::Service::Representative.find_by(representative_id: '82391')
          expect(veteran_rep).to be_nil
        end
      end

      context 'when the last_name has trailing white space' do
        it 'removes the trailing white space' do
          veteran_rep = Veteran::Service::Representative.find_by(representative_id: '8240')
          expect(veteran_rep.last_name).to eq('Good')
        end
      end
    end
  end
end
