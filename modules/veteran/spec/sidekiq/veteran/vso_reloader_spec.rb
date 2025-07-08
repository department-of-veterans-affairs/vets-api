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

  describe 'validation logic' do
    let(:reloader) { Veteran::VSOReloader.new }

    before do
      # Create existing representatives and organizations with unique IDs
      100.times { |i| create(:veteran_representative, representative_id: "ATT#{i}", user_types: ['attorney']) }
      50.times { |i| create(:veteran_representative, representative_id: "CA#{i}", user_types: ['claim_agents']) }
      75.times do |i|
        create(:veteran_representative, representative_id: "VSO#{i}", user_types: ['veteran_service_officer'])
      end
      create_list(:organization, 20)

      # Create previous accreditation total
      Veteran::AccreditationTotal.create!(
        attorneys: 100,
        claims_agents: 50,
        vso_representatives: 75,
        vso_organizations: 20,
        created_at: 1.day.ago
      )
    end

    describe '#valid_count?' do
      before { reloader.send(:ensure_initial_counts) }

      it 'allows updates when count increases' do
        expect(reloader.send(:valid_count?, :attorneys, 110)).to be true
      end

      it 'allows updates when count stays the same' do
        expect(reloader.send(:valid_count?, :attorneys, 100)).to be true
      end

      it 'blocks updates when decrease exceeds threshold' do
        # 75 attorneys is a 25% decrease, which exceeds 20% threshold
        expect(SlackNotify::Client).to receive(:new).with(
          hash_including(channel: '#benefits-representation-management-notifications')
        ).and_return(double(notify: true))
        expect(reloader.send(:valid_count?, :attorneys, 75)).to be false
      end

      it 'allows updates when decrease is within threshold' do
        # 85 attorneys is a 15% decrease, which is within 20% threshold
        expect(reloader.send(:valid_count?, :attorneys, 85)).to be true
      end

      context 'with no previous count' do
        before do
          Veteran::AccreditationTotal.destroy_all
        end

        it 'allows any count when no history exists' do
          # Create a fresh reloader instance with mocked initial counts
          fresh_reloader = Veteran::VSOReloader.new
          allow(fresh_reloader).to receive(:fetch_initial_counts).and_return({
                                                                               attorneys: 0,
                                                                               claims_agents: 0,
                                                                               vso_representatives: 0,
                                                                               vso_organizations: 0
                                                                             })
          fresh_reloader.send(:ensure_initial_counts)

          allow_any_instance_of(SlackNotify::Client).to receive(:notify)
          expect(fresh_reloader.send(:valid_count?, :attorneys, 50)).to be true
        end
      end

      context 'with no stored count for a type' do
        before do
          # Create a record with no attorney count (simulating first run or after reset)
          Veteran::AccreditationTotal.create!(
            attorneys: nil,
            claims_agents: 50,
            vso_representatives: 75,
            vso_organizations: 20,
            created_at: 1.hour.ago
          )
        end

        it 'uses the current count from the database when no previous value exists' do
          # Should use the initial count from the database since the latest record has nil
          initial_counts = reloader.instance_variable_get(:@initial_counts)
          expect(reloader.send(:get_previous_count, :attorneys)).to eq initial_counts[:attorneys]
        end
      end
    end

    describe '#notify_threshold_exceeded' do
      before { reloader.send(:ensure_initial_counts) }

      it 'sends notification to the correct Slack channel' do
        expect(SlackNotify::Client).to receive(:new).with(
          hash_including(
            webhook_url: Settings.claims_api.slack.webhook_url,
            channel: '#benefits-representation-management-notifications',
            username: 'VSOReloader'
          )
        ).and_return(double(notify: true))

        reloader.send(:notify_threshold_exceeded, :attorneys, 100, 70, 0.30, 0.20)
      end

      it 'logs to Sentry' do
        expect(SlackNotify::Client).to receive(:new).with(
          hash_including(channel: '#benefits-representation-management-notifications')
        ).and_return(double(notify: true))

        expect(reloader).to receive(:log_message_to_sentry).with(
          'VSO Reloader threshold exceeded for attorneys',
          :warn,
          hash_including(previous_count: 100, new_count: 70, decrease_percentage: 0.30)
        )
        reloader.send(:notify_threshold_exceeded, :attorneys, 100, 70, 0.30, 0.20)
      end
    end

    describe '#save_accreditation_totals' do
      before do
        reloader.send(:ensure_initial_counts)
        reloader.instance_variable_set(:@validation_results, {
                                         attorneys: 95,
                                         claims_agents: nil, # This one failed validation
                                         vso_representatives: 70,
                                         vso_organizations: 19
                                       })
      end

      it 'creates a new AccreditationTotal record with validation results' do
        expect { reloader.send(:save_accreditation_totals) }.to change(Veteran::AccreditationTotal, :count).by(1)

        total = Veteran::AccreditationTotal.last
        expect(total.attorneys).to eq 95
        expect(total.claims_agents).to be_nil
        expect(total.vso_representatives).to eq 70
        expect(total.vso_organizations).to eq 19
      end
    end

    describe 'full perform cycle with validation' do
      before { reloader.send(:ensure_initial_counts) }

      context 'when all counts pass validation' do
        it 'updates all representative types' do
          VCR.use_cassette('veteran/ogc_poa_data') do
            # Mock validation to always pass and set the validation results
            allow_any_instance_of(Veteran::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count|
              instance.instance_variable_get(:@validation_results)[rep_type] = new_count
              true
            end

            expect { reloader.perform }.to change(Veteran::AccreditationTotal, :count).by(1)

            total = Veteran::AccreditationTotal.last
            expect(total.attorneys).to be_present
            expect(total.claims_agents).to be_present
            expect(total.vso_representatives).to be_present
            expect(total.vso_organizations).to be_present
          end
        end
      end

      context 'when some counts fail validation' do
        it 'only updates types that pass validation' do
          VCR.use_cassette('veteran/ogc_poa_data') do
            # Mock validation with proper result setting
            allow_any_instance_of(Veteran::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count|
              if rep_type == :attorneys
                instance.instance_variable_get(:@validation_results)[rep_type] = nil
                false
              else
                instance.instance_variable_get(:@validation_results)[rep_type] = new_count
                true
              end
            end

            # Don't expect the Slack notification since we're mocking valid_count? entirely

            reloader.perform

            total = Veteran::AccreditationTotal.last
            expect(total.attorneys).to be_nil
            expect(total.claims_agents).to be_present
            expect(total.vso_representatives).to be_present
            expect(total.vso_organizations).to be_present
          end
        end
      end

      context 'when VSO representative or organization count fails validation' do
        it 'skips processing both VSO reps and orgs to maintain data integrity' do
          VCR.use_cassette('veteran/ogc_poa_data') do
            # Mock validation to fail for VSO organizations only
            allow_any_instance_of(Veteran::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count|
              if rep_type == :vso_organizations
                # Simulate organization count failing validation
                instance.instance_variable_get(:@validation_results)[rep_type] = nil
                false
              else
                # All other types pass validation (including VSO representatives)
                instance.instance_variable_get(:@validation_results)[rep_type] = new_count
                true
              end
            end

            # Expect that VSO representatives are NOT deleted even though their count passed validation
            # because the organization count failed
            initial_vso_rep_count = Veteran::Service::Representative
                                    .where("'#{Veteran::VSOReloader::USER_TYPE_VSO}' = ANY(user_types)")
                                    .count
            initial_org_count = Veteran::Service::Organization.count

            reloader.perform

            # Both VSO reps and orgs should remain unchanged
            expect(Veteran::Service::Representative
                    .where("'#{Veteran::VSOReloader::USER_TYPE_VSO}' = ANY(user_types)")
                    .count).to eq initial_vso_rep_count
            expect(Veteran::Service::Organization.count).to eq initial_org_count

            # Check the saved totals
            total = Veteran::AccreditationTotal.last
            expect(total.vso_representatives).to be_present
            expect(total.vso_organizations).to be_nil
          end
        end
      end

      context 'when manual reprocessing occurs' do
        it 'saves all counts in AccreditationTotal, not just manually processed types' do
          VCR.use_cassette('veteran/ogc_poa_data') do
            # Simulate manual reprocessing of only attorneys (like the rake task does)
            # by having validation pass only for attorneys
            allow_any_instance_of(Veteran::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count|
              if rep_type == :attorneys
                instance.instance_variable_get(:@validation_results)[rep_type] = new_count
                true
              else
                # Don't add other types to validation_results at all
                # This simulates them not being processed
                false
              end
            end

            # Override reload methods to simulate only attorneys being processed
            allow(reloader).to receive_messages(reload_claim_agents: [], reload_vso_reps: [])

            reloader.perform

            # Check that the saved total has all counts, not just attorneys
            total = Veteran::AccreditationTotal.last
            expect(total.attorneys).to be_present
            # These should have current counts from the database, not nil
            initial_counts = reloader.instance_variable_get(:@initial_counts)
            expect(total.claims_agents).to eq(initial_counts[:claims_agents])
            expect(total.vso_representatives).to eq(initial_counts[:vso_representatives])
            expect(total.vso_organizations).to eq(initial_counts[:vso_organizations])
          end
        end
      end
    end
  end
end
