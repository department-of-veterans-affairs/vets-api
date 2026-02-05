# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::VSOReloader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  describe 'importer' do
    it 'reloads data from pulldown' do
      VCR.use_cassette('representation_management/representation_management_ogc_poa_data') do
        RepresentationManagement::AccreditationTotal.destroy_all
        RepresentationManagement::VSOReloader.new.perform
        expect(AccreditedIndividual.count).to eq 435
        expect(AccreditedOrganization.count).to eq 3
        expect(AccreditedIndividual.attorneys.count).to eq 241
        expect(AccreditedIndividual.representatives.count).to eq 152
        expect(AccreditedIndividual.claims_agents.count).to eq 42
        expect(AccreditedIndividual.where(registration_number: '').count).to eq 0
      end
    end

    it 'loads attorneys with the poa codes loaded' do
      VCR.use_cassette('representation_management/representation_management_ogc_attorney_data') do
        RepresentationManagement::AccreditationTotal.destroy_all
        RepresentationManagement::VSOReloader.new.reload_attorneys
        expect(AccreditedIndividual.last.poa_code).to eq('9GB')
        expect(AccreditedIndividual.where(registration_number: '').count).to eq 0
      end
    end

    it 'loads a claims agent with the poa code' do
      VCR.use_cassette('representation_management/representation_management_ogc_claim_agent_data') do
        RepresentationManagement::AccreditationTotal.destroy_all
        RepresentationManagement::VSOReloader.new.reload_claim_agents

        claims_agent = AccreditedIndividual.find_by(registration_number: 42_535)
        expect(claims_agent.poa_code).to eq('FDN')
        expect(AccreditedIndividual.where(registration_number: '').count).to eq 0
      end
    end

    it 'loads a vso rep with the poa code' do
      VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
        RepresentationManagement::AccreditationTotal.destroy_all
        RepresentationManagement::VSOReloader.new.reload_vso_reps

        rep = AccreditedIndividual.find_by(registration_number: 8240)
        expect(rep.poa_code).to eq('095')
        expect(AccreditedIndividual.where(registration_number: '').count).to eq 0
      end
    end

    context 'existing organizations' do
      let(:org) do
        create(:accredited_organization, poa_code: '091', name: 'Testing', phone: '222-555-5555', state_code: 'ZZ',
                                         city: 'New York')
      end

      it 'only updates name, phone, and state' do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          expect(org.name).to eq('Testing')
          expect(org.phone).to eq('222-555-5555')
          expect(org.state_code).to eq('ZZ')
          expect(org.city).to eq('New York')

          RepresentationManagement::VSOReloader.new.reload_vso_reps
          org.reload

          expect(org.name).to eq('African American PTSD Association')
          expect(org.phone).to eq('253-589-0766')
          expect(org.state_code).to eq('WA')
          expect(org.city).to eq('New York')
        end
      end
    end

    context 'stale organization removal' do
      it 'removes organizations whose POA is not in the vso_data' do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          # Create a stale organization with a POA code not in the fixture data
          # Fixture contains POA codes: 091, ZZZ, 095
          stale_org = create(:accredited_organization, poa_code: 'XXX', name: 'Stale Organization')

          expect(AccreditedOrganization.find_by(poa_code: 'XXX')).to eq(stale_org)

          RepresentationManagement::VSOReloader.new.reload_vso_reps

          # Stale organization should be removed
          expect(AccreditedOrganization.find_by(poa_code: 'XXX')).to be_nil
        end
      end

      it 'preserves organizations whose POA is still in the vso_data' do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          # Create an organization with a POA that IS in the fixture data
          create(:accredited_organization, poa_code: '091', name: 'Old Name')

          RepresentationManagement::VSOReloader.new.reload_vso_reps

          # Organization should still exist (and be updated)
          expect(AccreditedOrganization.find_by(poa_code: '091')).to be_present
          expect(AccreditedOrganization.find_by(poa_code: '091').name).to eq('African American PTSD Association')
        end
      end

      it 'does not remove stale organizations when validation fails' do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          # Create a stale organization
          stale_org = create(:accredited_organization, poa_code: 'XXX', name: 'Stale Organization')

          # Create initial counts that will cause validation to fail
          RepresentationManagement::AccreditationTotal.create!(
            attorneys: 100,
            claims_agents: 50,
            vso_representatives: 1000, # Set high count so new count will fail validation
            vso_organizations: 1000,   # Set high count so new count will fail validation
            created_at: 1.day.ago
          )

          reloader = RepresentationManagement::VSOReloader.new
          reloader.reload_vso_reps

          # Stale organization should NOT be removed because validation failed
          expect(AccreditedOrganization.find_by(poa_code: 'XXX')).to eq(stale_org)
        end
      end
    end

    describe "storing a VSO Rep's middle initial" do
      it 'stores the middle initial if it exists' do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          RepresentationManagement::VSOReloader.new.reload_vso_reps

          veteran_rep = AccreditedIndividual.find_by!(first_name: 'Edgar', last_name: 'Anderson')
          expect(veteran_rep.middle_initial).to eq('B')
        end
      end

      it 'does not break if a middle initial does not exist' do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data_no_middle_initial') do
          RepresentationManagement::AccreditationTotal.destroy_all
          RepresentationManagement::VSOReloader.new.reload_vso_reps

          veteran_rep = AccreditedIndividual.find_by!(first_name: 'Edgar', last_name: 'Anderson')
          expect(veteran_rep.middle_initial).to eq('')
        end
      end
    end

    context 'leaving test users alone' do
      before do
        AccreditedIndividual.create(
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373b',
          registration_number: '98765',
          first_name: 'Tamara',
          last_name: 'Ellis',
          individual_type: 'representative',
          poa_code: '067'
        )

        AccreditedIndividual.create(
          registration_number: '12345',
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373b',
          first_name: 'John',
          last_name: 'Doe',
          individual_type: 'representative',
          poa_code: '072'
        )
      end

      it 'does not destroy test users' do
        VCR.use_cassette('representation_management/representation_management_ogc_poa_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          RepresentationManagement::VSOReloader.new.perform
          expect(AccreditedIndividual.where(first_name: 'Tamara', last_name: 'Ellis').count).to eq 1
          expect(AccreditedIndividual.where(first_name: 'John', last_name: 'Doe').count).to eq 1
        end
      end
    end

    context 'with a failed connection' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                               'some message')
      end

      it 'notifies slack' do
        allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:log_to_slack)
        expect_any_instance_of(RepresentationManagement::VSOReloader).to receive(:log_to_slack)
        RepresentationManagement::VSOReloader.new.perform
      end
    end

    context 'with a client error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
      end

      it 'notifies slack' do
        allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:log_to_slack)
        expect_any_instance_of(RepresentationManagement::VSOReloader).to receive(:log_to_slack)
        RepresentationManagement::VSOReloader.new.perform
      end
    end

    context 'handling names' do
      before do
        VCR.use_cassette('representation_management/representation_management_ogc_vso_rep_data') do
          RepresentationManagement::AccreditationTotal.destroy_all
          RepresentationManagement::VSOReloader.new.reload_vso_reps
        end
      end

      context 'with multiple first names' do
        it 'handles it correctly' do
          veteran_rep = AccreditedIndividual.find_by!(registration_number: '82390')
          expect(veteran_rep.first_name).to eq('Anna Mae')
          expect(veteran_rep.middle_initial).to eq('B')
        end
      end

      context 'invalid name' do
        it 'handles it correctly' do
          veteran_rep = AccreditedIndividual.find_by(registration_number: '82391')
          expect(veteran_rep).to be_nil
        end
      end

      context 'when the last_name has trailing white space' do
        it 'removes the trailing white space' do
          veteran_rep = AccreditedIndividual.find_by(registration_number: '8240')
          expect(veteran_rep.last_name).to eq('Good')
        end
      end
    end
  end

  describe 'dedup by registration_number (attorney)' do
    let(:reloader) { RepresentationManagement::VSOReloader.new }

    before do
      RepresentationManagement::AccreditationTotal.destroy_all
    end

    it 'does not create a duplicate when names vary' do
      AccreditedIndividual.create!(
        registration_number: 'A123',
        ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373b',
        first_name: 'Sarah',
        last_name: 'Whitman',
        individual_type: 'attorney',
        poa_code: 'XYZ'
      )

      payload = {
        'Registration Num' => 'A123',
        'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373b',
        'First Name' => 'Sara',
        'Last Name' => 'Whittman',
        'Phone' => '202-555-0101',
        'POA Code' => '9GB'
      }

      expect do
        reloader.send(:find_or_create_attorneys, payload)
      end.not_to change(AccreditedIndividual, :count)

      rep = AccreditedIndividual.find_by(registration_number: 'A123')
      expect(rep.first_name).to eq('Sarah')
      expect(rep.last_name).to  eq('Whitman')
      expect(rep.individual_type).to eq('attorney')
      expect(rep.poa_code).to eq('9GB')
    end
  end

  describe 'initial attribute population for new reps' do
    let(:reloader) { RepresentationManagement::VSOReloader.new }

    before do
      RepresentationManagement::AccreditationTotal.destroy_all
    end

    it 'fills names/contacts for a NEW attorney record' do
      payload = {
        'Registration Num' => 'A999',
        'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373b',
        'First Name' => 'June',
        'Last Name' => 'Park',
        'Phone' => '202-555-0123',
        'POA Code' => 'ABC'
      }

      expect do
        reloader.send(:find_or_create_attorneys, payload)
      end.to change(AccreditedIndividual, :count).by(1)

      rep = AccreditedIndividual.find_by!(registration_number: 'A999')
      expect(rep.first_name).to eq('June')
      expect(rep.last_name).to  eq('Park')
      expect(rep.phone).to      eq('202-555-0123')
      expect(rep.individual_type).to eq('attorney')
      expect(rep.poa_code).to eq('ABC')
    end

    it 'fills names/contacts for a NEW claim agent record' do
      payload = {
        'Registration Num' => 'C321',
        'AccrClaimAgentId' => '9c6f8595-4e84-42e5-b90a-270c422c373b',
        'First Name' => 'Leo',
        'Last Name' => 'Ng',
        'Phone' => '202-555-0144',
        'POA Code' => 'FDN'
      }

      expect do
        reloader.send(:find_or_create_claim_agents, payload)
      end.to change(AccreditedIndividual, :count).by(1)

      rep = AccreditedIndividual.find_by!(registration_number: 'C321')
      expect(rep.first_name).to eq('Leo')
      expect(rep.last_name).to  eq('Ng')
      expect(rep.phone).to      eq('202-555-0144')
      expect(rep.individual_type).to eq('claims_agent')
      expect(rep.poa_code).to eq('FDN')
    end
  end

  describe 'set semantics for array attributes' do
    let(:reloader) { RepresentationManagement::VSOReloader.new }

    it 'does not duplicate individual_type or poa_code when reprocessing' do
      RepresentationManagement::AccreditationTotal.destroy_all
      rep = AccreditedIndividual.create!(
        ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373b',
        registration_number: 'S111',
        first_name: 'Sam',
        last_name: 'Hill',
        individual_type: 'attorney',
        poa_code: 'XYZ'
      )

      payload = {
        'Registration Num' => 'S111',
        'First Name' => 'Samuel',
        'Last Name' => 'Hill',
        'Phone' => '202-555-0000',
        'POA Code' => 'XYZ'
      }

      expect do
        reloader.send(:find_or_create_attorneys, payload)
      end.not_to change(AccreditedIndividual, :count)

      rep.reload
      expect(rep.individual_type).to eq('attorney')
      expect(rep.poa_code).to eq('XYZ')
    end
  end

  describe 'validation logic' do
    let(:reloader) { RepresentationManagement::VSOReloader.new }

    before do
      # Create existing representatives and organizations with unique IDs
      100.times { |i| create(:accredited_individual, registration_number: "ATT#{i}", individual_type: 'attorney') }
      50.times { |i| create(:accredited_individual, registration_number: "CA#{i}", individual_type: 'claims_agent') }
      75.times do |i|
        create(:accredited_individual, registration_number: "VSO#{i}", individual_type: 'representative')
      end
      create_list(:organization, 20)

      # Create previous accreditation total
      RepresentationManagement::AccreditationTotal.create!(
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
        expect(reloader.send(:valid_count?, :attorneys, 75)).to be false
      end

      it 'notifies slack when the decrease exceeds threshold' do
        allow(reloader).to receive(:notify_threshold_exceeded)
        expect(reloader).to receive(:notify_threshold_exceeded).with(
          :attorneys, 100, 75, anything, anything
        )
        reloader.send(:valid_count?, :attorneys, 75)
      end

      it 'allows updates when decrease is within threshold' do
        # 85 attorneys is a 15% decrease, which is within 20% threshold
        expect(reloader.send(:valid_count?, :attorneys, 85)).to be true
      end

      context 'with no previous count' do
        before do
          RepresentationManagement::AccreditationTotal.destroy_all
        end

        it 'allows any count when no history exists' do
          # Create a fresh reloader instance with mocked initial counts
          fresh_reloader = RepresentationManagement::VSOReloader.new
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
          RepresentationManagement::AccreditationTotal.create!(
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

      it 'sends a notification to Slack' do
        allow(reloader).to receive(:log_to_slack)

        expect(reloader).to receive(:log_to_slack).with(
          include('Attorneys count decreased beyond threshold!')
        )

        reloader.send(:notify_threshold_exceeded, :attorneys, 100, 70, 0.30, 0.20)
      end

      it 'logs to Sentry' do
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
        expect do
          reloader.send(:save_accreditation_totals)
        end.to change(RepresentationManagement::AccreditationTotal, :count).by(1)

        total = RepresentationManagement::AccreditationTotal.last
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
          VCR.use_cassette('representation_management/representation_management_ogc_poa_data') do
            # Mock validation to always pass and set the validation results
            allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count| # rubocop:disable Layout/LineLength
              instance.instance_variable_get(:@validation_results)[rep_type] = new_count
              true
            end

            expect { reloader.perform }.to change(RepresentationManagement::AccreditationTotal, :count).by(1)

            total = RepresentationManagement::AccreditationTotal.last
            expect(total.attorneys).to be_present
            expect(total.claims_agents).to be_present
            expect(total.vso_representatives).to be_present
            expect(total.vso_organizations).to be_present
          end
        end
      end

      context 'when some counts fail validation' do
        it 'only updates types that pass validation' do
          VCR.use_cassette('representation_management/representation_management_ogc_poa_data') do
            # Mock validation with proper result setting
            allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count| # rubocop:disable Layout/LineLength
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

            total = RepresentationManagement::AccreditationTotal.last
            expect(total.attorneys).to be_nil
            expect(total.claims_agents).to be_present
            expect(total.vso_representatives).to be_present
            expect(total.vso_organizations).to be_present
          end
        end
      end

      context 'when VSO representative or organization count fails validation' do
        it 'skips processing both VSO reps and orgs to maintain data integrity' do
          VCR.use_cassette('representation_management/representation_management_ogc_poa_data') do
            # Mock validation to fail for VSO organizations only
            allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count| # rubocop:disable Layout/LineLength
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
            initial_vso_rep_count = AccreditedIndividual
                                    .where(individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE)
                                    .count
            initial_org_count = AccreditedOrganization.count

            reloader.perform

            # Both VSO reps and orgs should remain unchanged
            expect(AccreditedIndividual
                     .where(individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE)
                     .count).to eq initial_vso_rep_count
            expect(AccreditedOrganization.count).to eq initial_org_count

            # Check the saved totals
            total = RepresentationManagement::AccreditationTotal.last
            expect(total.vso_representatives).to be_present
            expect(total.vso_organizations).to be_nil
          end
        end
      end

      context 'when manual reprocessing occurs' do
        it 'saves all counts in AccreditationTotal, not just manually processed types' do
          VCR.use_cassette('representation_management/representation_management_ogc_poa_data') do
            # Simulate manual reprocessing of only attorneys (like the rake task does)
            # by having validation pass only for attorneys
            allow_any_instance_of(RepresentationManagement::VSOReloader).to receive(:valid_count?) do |instance, rep_type, new_count| # rubocop:disable Layout/LineLength
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
            total = RepresentationManagement::AccreditationTotal.last
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
