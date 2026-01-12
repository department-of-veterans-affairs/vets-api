# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client'
require 'stringio'

describe MedicalRecords::Client do
  context 'when a valid session exists', :vcr do
    before do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_support_new_model_allergy).and_return(false)
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_support_new_model_health_condition).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_support_new_model_vaccine).and_return(false)

      VCR.use_cassette 'mr_client/session' do
        VCR.use_cassette 'mr_client/get_a_patient_by_identifier' do
          @client ||= begin
            client = MedicalRecords::Client.new(session: { user_uuid: '12345', user_id: '22406991' },
                                                icn: '1013868614V792025')
            client.authenticate
            client
          end
        end
      end

      MedicalRecords::Client.send(:public, *MedicalRecords::Client.protected_instance_methods)
    end

    after do
      MedicalRecords::Client.send(:protected, *MedicalRecords::Client.protected_instance_methods)
    end

    let(:client) { @client }
    let(:entries) { ['Entry 1', 'Entry 2', 'Entry 3', 'Entry 4', 'Entry 5'] }

    context 'when new-model flipper flags are enabled' do
      let(:user_uuid)    { 'user-123' }
      let(:allergy_key)  { "#{user_uuid}-allergies" }
      let(:vac_key)      { "#{user_uuid}-vaccines" }
      let(:cond_key)     { "#{user_uuid}-conditions" }
      let(:fake_bundle)  { double('FHIR::Bundle', entry: []) }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_new_model_allergy).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_new_model_health_condition).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_new_model_vaccine).and_return(true)

        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_backend_allergy).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_backend_health_condition).and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_backend_pagination_vaccine).and_return(true)
      end

      shared_examples 'a transformed-record list' do |method_name, model_class, fhir_resource_class, key_suffix|
        # Build the cache key dynamically from the user_uuid and suffix:
        let(:cache_key) { "#{user_uuid}-#{key_suffix}" }
        let(:fake_bundle) { double('FHIR::Bundle', entry: []) }

        # Shared setup for FHIR fetch scenarios
        shared_context 'fhir fetch setup' do |flipper_flags|
          let(:fetched_resources) { [double('resA'), double('resB')] }
          let(:resource_wrappers) { fetched_resources.map { |r| double(resource: r) } }
          let(:model_objs)        { [double('objA'), double('objB')] }
          let(:fake_collection)   { double('Vets::Collection', records: model_objs) }

          before do
            flipper_flags.each do |flag, value|
              allow(Flipper).to receive(:enabled?).with(flag).and_return(value)
            end
            allow(model_class).to receive(:get_cached)
            allow(client).to receive(:fhir_search).and_return(fake_bundle)
            allow(fake_bundle).to receive(:entry).and_return(resource_wrappers)
            allow(model_class).to receive(:from_fhir).and_return(*model_objs)
            allow(model_class).to receive(:set_cached)
            allow(Vets::Collection).to receive(:new)
              .with(model_objs, model_class)
              .and_return(fake_collection)
          end
        end

        describe "##{method_name}" do
          context 'when cache is present' do
            let(:cached_records) { [double('r1'), double('r2')] }
            let(:fake_collection) { double('Vets::Collection', records: cached_records) }

            before do
              # Return an array of “cached_records” so that client.list_* returns data from cache
              allow(model_class).to receive(:get_cached).with(cache_key).and_return(cached_records)
              # Prevent any FHIR calls from happening
              allow(client).to receive(:fhir_search)
              # Build a Vets::Collection around the cached records
              allow(Vets::Collection).to receive(:new)
                .with(cached_records, model_class)
                .and_return(fake_collection)
            end

            it 'returns a Vets::Collection built from the cache and does not call FHIR' do
              coll = client.send(method_name, user_uuid)
              expect(coll).to eq(fake_collection)
              expect(client).not_to have_received(:fhir_search)
            end
          end

          context 'when cache is empty' do
            let(:fetched_resources) { [double('res1'), double('res2')] }
            let(:resource_wrappers) { fetched_resources.map { |r| double(resource: r) } }
            let(:model_objs)        { [double('m1'), double('m2')] }
            let(:fake_collection)   { double('Vets::Collection', records: model_objs) }

            before do
              # Simulate no cache so get_cached returns nil
              allow(model_class).to receive(:get_cached).with(cache_key).and_return(nil)
              # When fhir_search is called, return the fake_bundle
              allow(client).to receive(:fhir_search).and_return(fake_bundle)
              # Simulate that fake_bundle.entry yields two entries, each wrapping one fetched_resource
              allow(fake_bundle).to receive(:entry).and_return(resource_wrappers)
              # Each fetched_resource will be turned into one model object
              allow(model_class).to receive(:from_fhir).and_return(*model_objs)
              # Ensure set_cached is stubbed so we can verify it was called
              allow(model_class).to receive(:set_cached)
              # Finally, build a Vets::Collection around the two model_objs
              allow(Vets::Collection).to receive(:new)
                .with(model_objs, model_class)
                .and_return(fake_collection)
            end

            it 'fetches via FHIR, wraps in Vets::Collection, and writes to cache' do
              coll = client.send(method_name, user_uuid)
              expect(client).to have_received(:fhir_search).with(
                fhir_resource_class,
                search: hash_including(parameters: hash_including(patient: anything))
              )
              expect(model_class).to have_received(:set_cached).with(cache_key, model_objs)
              expect(coll).to eq(fake_collection)
            end
          end

          context 'when cache is disabled (use_cache: false)' do
            include_context 'fhir fetch setup', {}
            it 'bypasses cache and fetches via FHIR, writes to cache, and returns Vets::Collection' do
              coll = client.send(method_name, user_uuid, use_cache: false)
              expect(model_class).not_to have_received(:get_cached)
              expect(client).to have_received(:fhir_search).with(
                fhir_resource_class,
                search: hash_including(parameters: hash_including(patient: anything))
              )
              expect(model_class).to have_received(:set_cached).with(cache_key, model_objs)
              expect(coll).to eq(fake_collection)
            end
          end

          context 'when backend pagination flags are false' do
            include_context 'fhir fetch setup', {
              mhv_medical_records_support_backend_pagination_allergy: false,
              mhv_medical_records_support_backend_pagination_health_condition: false,
              mhv_medical_records_support_backend_pagination_vaccine: false
            }
            it 'does not use the cache and fetches via FHIR' do
              coll = client.send(method_name, user_uuid, use_cache: true)
              expect(model_class).not_to have_received(:get_cached)
              expect(client).to have_received(:fhir_search).with(
                fhir_resource_class,
                search: hash_including(parameters: hash_including(patient: anything))
              )
              expect(model_class).to have_received(:set_cached).with(cache_key, model_objs)
              expect(coll).to eq(fake_collection)
            end
          end
        end
      end

      describe '#list_allergies' do
        it_behaves_like 'a transformed-record list',
                        :list_allergies,
                        MHV::MR::Allergy,
                        FHIR::AllergyIntolerance,
                        'allergies'
      end

      describe '#get_allergy' do
        let(:allergy_id) { 30_242 }

        it 'gets a single allergy using the new model', :vcr do
          VCR.use_cassette 'mr_client/get_an_allergy' do
            allergy = client.get_allergy(allergy_id)
            expect(allergy).to be_a(MHV::MR::Allergy)
          end
        end
      end

      describe '#list_vaccines' do
        it_behaves_like 'a transformed-record list',
                        :list_vaccines,
                        MHV::MR::Vaccine,
                        FHIR::Immunization,
                        'vaccines'
      end

      describe '#get_vaccine' do
        it 'gets a single vaccine', :vcr do
          VCR.use_cassette 'mr_client/get_a_vaccine' do
            vaccine = client.get_vaccine(2_954)
            expect(vaccine).to be_a(MHV::MR::Vaccine)
          end
        end
      end

      describe '#list_conditions' do
        it_behaves_like 'a transformed-record list',
                        :list_conditions,
                        MHV::MR::HealthCondition,
                        FHIR::Condition,
                        'conditions'
      end

      describe '#get_condition' do
        it 'gets a single health condition', :vcr do
          VCR.use_cassette 'mr_client/get_a_health_condition' do
            condition = client.get_condition(4169)
            expect(condition).to be_a(MHV::MR::HealthCondition)
          end
        end
      end
    end

    describe 'Getting a patient by identifier' do
      let(:patient_id) { 12_345 }

      it 'adds adds a custom header to bypass FHIR server cache', :vcr do
        VCR.use_cassette 'mr_client/get_a_patient_by_identifier' do
          client.get_patient_by_identifier(client.fhir_client, patient_id)
          expect(
            a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
          ).to have_been_made.at_least_once
        end
      end
    end

    it 'gets a list of allergies', :vcr do
      VCR.use_cassette 'mr_client/get_a_list_of_allergies' do
        allergy_list = client.list_allergies('uuid')
        expect(
          a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
        ).to have_been_made.at_least_once
        expect(allergy_list).to be_a(FHIR::Bundle)
        # Verify that the list is sorted reverse chronologically (with nil values to the end).
        allergy_list.entry.each_cons(2) do |prev, curr|
          prev_date = prev.resource.recordedDate
          curr_date = curr.resource.recordedDate
          expect(curr_date.nil? || prev_date >= curr_date).to be true
        end
      end
    end

    it 'gets a single allergy', :vcr do
      VCR.use_cassette 'mr_client/get_an_allergy' do
        allergy_id = 30_242
        allergy = client.get_allergy(allergy_id)
        expect(allergy).to be_a(FHIR::AllergyIntolerance)
        expect(allergy.id).to eq(allergy_id.to_s)
      end
    end

    it 'gets a list of vaccines', :vcr do
      VCR.use_cassette 'mr_client/get_a_list_of_vaccines' do
        vaccine_list = client.list_vaccines('uuid')
        expect(vaccine_list).to be_a(FHIR::Bundle)
        expect(
          a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
        ).to have_been_made.at_least_once
        # Verify that the list is sorted reverse chronologically (with nil values to the end).
        vaccine_list.entry.each_cons(2) do |prev, curr|
          prev_date = prev.resource.occurrenceDateTime
          curr_date = curr.resource.occurrenceDateTime
          expect(curr_date.nil? || prev_date >= curr_date).to be true
        end
      end
    end

    it 'gets a single vaccine', :vcr do
      VCR.use_cassette 'mr_client/get_a_vaccine' do
        vaccine = client.get_vaccine(2_954)
        expect(vaccine).to be_a(FHIR::Immunization)
      end
    end

    it 'gets a list of vitals', :vcr do
      VCR.use_cassette 'mr_client/get_a_list_of_vitals' do
        vitals_list = client.list_vitals
        expect(vitals_list).to be_a(FHIR::Bundle)
        expect(
          a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
        ).to have_been_made.at_least_once
        # Verify that the list is sorted reverse chronologically (with nil values to the end).
        vitals_list.entry.each_cons(2) do |prev, curr|
          prev_date = prev.resource.effectiveDateTime
          curr_date = curr.resource.effectiveDateTime
          expect(curr_date.nil? || prev_date >= curr_date).to be true
        end
      end
    end

    it 'gets a list of health conditions', :vcr do
      VCR.use_cassette 'mr_client/get_a_list_of_health_conditions' do
        condition_list = client.list_conditions('uuid')
        expect(
          a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
        ).to have_been_made.at_least_once
        expect(condition_list).to be_a(FHIR::Bundle)
        # Verify that the list is sorted reverse chronologically (with nil values to the end).
        condition_list.entry.each_cons(2) do |prev, curr|
          prev_date = prev.resource.recordedDate
          curr_date = curr.resource.recordedDate
          expect(curr_date.nil? || prev_date >= curr_date).to be true
        end
      end
    end

    it 'gets a single health condition', :vcr do
      VCR.use_cassette 'mr_client/get_a_health_condition' do
        condition = client.get_condition(4169)
        expect(condition).to be_a(FHIR::Condition)
      end
    end

    it 'gets a list of care summaries & notes', :vcr do
      VCR.use_cassette 'mr_client/get_a_list_of_clinical_notes' do
        note_list = client.list_clinical_notes
        expect(
          a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
        ).to have_been_made.at_least_once
        expect(note_list).to be_a(FHIR::Bundle)
        # Verify that the list is sorted reverse chronologically (with nil values to the end).
        note_list.entry.each_cons(2) do |prev, curr|
          prev_date = prev.resource.context&.period&.end || prev.resource.date
          curr_date = curr.resource.context&.period&.end || curr.resource.date
          expect(curr_date.nil? || prev_date >= curr_date).to be true
        end
      end
    end

    it 'gets a list of labs & tests', :vcr do
      VCR.use_cassette 'mr_client/get_a_list_of_chemhem_labs' do
        chemhem_list = client.list_labs_and_tests
        expect(chemhem_list).to be_a(FHIR::Bundle)
        # Verify that the list is sorted reverse chronologically (with nil values to the end).
        chemhem_list.entry.each_cons(2) do |prev, curr|
          prev_date = prev.resource.effectiveDateTime
          curr_date = curr.resource.effectiveDateTime
          expect(curr_date.nil? || prev_date >= curr_date).to be true
        end
      end
    end

    it 'gets a single diagnostic report', :vcr do
      VCR.use_cassette 'mr_client/get_a_diagnostic_report' do
        report = client.get_diagnostic_report(1234)
        expect(report).to be_a(FHIR::DiagnosticReport)
      end
    end

    it 'gets a multi-page list of FHIR resources', :vcr do
      VCR.use_cassette 'mr_client/get_multiple_fhir_pages' do
        allergies_list = client.list_allergies('uuid')
        expect(allergies_list).to be_a(FHIR::Bundle)
        expect(allergies_list.total).to eq(5)
        expect(allergies_list.entry.count).to eq(5)
      end
    end

    describe('#sort_bundle') do
      describe 'sorting with non-nested fields' do
        let(:bundle) { FHIR::Bundle.new(entry: [entry1, entry2, entry3]) }
        let(:entry1) { FHIR::Bundle::Entry.new(resource: resource1) }
        let(:entry2) { FHIR::Bundle::Entry.new(resource: resource2) }
        let(:entry3) { FHIR::Bundle::Entry.new(resource: resource3) }
        let(:resource1) { FHIR::AllergyIntolerance.new(onsetDateTime: '2005') }
        let(:resource2) { FHIR::AllergyIntolerance.new(onsetDateTime: '2000') }
        let(:resource3) { FHIR::AllergyIntolerance.new(onsetDateTime: '2010') }
        let(:resource4) { FHIR::AllergyIntolerance.new }

        context 'when sorting by date in ascending order' do
          it 'returns the entries sorted by date' do
            sorted = client.sort_bundle(bundle, :onsetDateTime)
            expect(sorted.entry.map { |e| e.resource.onsetDateTime }).to eq(%w[2000 2005 2010])
          end
        end

        context 'when sorting by date in descending order' do
          it 'returns the entries sorted by date' do
            sorted = client.sort_bundle(bundle, :onsetDateTime, :desc)
            expect(sorted.entry.map { |e| e.resource.onsetDateTime }).to eq(%w[2010 2005 2000])
          end
        end

        context 'when one of the resources lacks the sorting field' do
          let(:bundle_with_missing_field) { FHIR::Bundle.new(entry: [entry1, entry4, entry2]) }
          let(:entry4) { FHIR::Bundle::Entry.new(resource: resource4) }

          context 'in ascending order' do
            it 'places the entry with the missing field at the end' do
              sorted = client.sort_bundle(bundle_with_missing_field, :onsetDateTime)
              expect(sorted.entry.last.resource.onsetDateTime).to be_nil
            end
          end

          context 'in descending order' do
            it 'places the entry with the missing field at the end' do
              sorted = client.sort_bundle(bundle_with_missing_field, :onsetDateTime, :desc)
              expect(sorted.entry.last.resource.onsetDateTime).to be_nil
            end
          end
        end
      end

      describe 'sorting with nested fields' do
        # Setup for creating a FHIR::Bundle with DocumentReference resources
        let(:bundle) { FHIR::Bundle.new }

        let(:doc_ref1) { FHIR::DocumentReference.new(id: '1', date: '2020-01-01', context: context1) }
        let(:context1) { FHIR::DocumentReference::Context.new(period: period1) }
        let(:period1) { FHIR::Period.new(start: '2020-01-01') }

        let(:doc_ref2) { FHIR::DocumentReference.new(id: '2', date: '2021-01-01') } # Missing nested field

        let(:doc_ref3) { FHIR::DocumentReference.new(id: '3', date: '2022-01-01', context: context3) }
        let(:context3) { FHIR::DocumentReference::Context.new(period: period3) }
        let(:period3) { FHIR::Period.new(start: '2022-01-01') }

        before do
          bundle.entry = [doc_ref1, doc_ref2, doc_ref3].map { |resource| FHIR::Bundle::Entry.new(resource:) }
        end

        it 'sorts by a nested field in ascending order' do
          sorted_bundle = client.sort_bundle(bundle, 'context.period.start', :asc)
          expect(sorted_bundle.entry.map { |e| e.resource.id }).to eq(%w[1 3 2]) # '3' last due to missing field
        end

        it 'sorts by a nested field in descending order' do
          sorted_bundle = client.sort_bundle(bundle, 'context.period.start', :desc)
          expect(sorted_bundle.entry.map { |e| e.resource.id }).to eq(%w[3 1 2]) # '3' last due to missing field
        end

        it 'handles sorting with a non-existent nested field path' do
          sorted_bundle = client.sort_bundle(bundle, 'context.period.end', :asc)
          expect( # All entries treated as having missing field
            sorted_bundle.entry.map do |e|
              e.resource.id
            end
          ).to eq(%w[1 2 3])
        end
      end
    end

    describe('#sort_bundle_with_criteria') do
      let(:bundle) { FHIR::Bundle.new(entry: [entry1, entry2, entry3]) }
      let(:entry1) { FHIR::Bundle::Entry.new(resource: resource1) }
      let(:entry2) { FHIR::Bundle::Entry.new(resource: resource2) }
      let(:entry3) { FHIR::Bundle::Entry.new(resource: resource3) }
      let(:resource1) { FHIR::Patient.new(birthDate: 1930) }
      let(:resource2) { FHIR::Patient.new(birthDate: 1945) }
      let(:resource3) { FHIR::Patient.new(birthDate: 1925) }

      context 'when sorting with mixed resource types' do
        let(:resource4) { FHIR::Observation.new(valueQuantity: FHIR::Quantity.new(value: 1940)) }
        let(:entry4) { FHIR::Bundle::Entry.new(resource: resource4) }

        before { bundle.entry << entry4 }

        it 'sorts based on a custom criteria handling different resource types' do
          sorted = client.sort_bundle_with_criteria(bundle) do |resource|
            case resource
            when FHIR::Patient
              resource.birthDate
            when FHIR::Observation
              resource.valueQuantity.value
            else
              0
            end
          end
          expected_order = [resource3, resource1, resource4, resource2] # [1925, 1930, 1940, 1945]
          expect(sorted.entry.map(&:resource)).to eq(expected_order)
        end
      end
    end

    describe '#fetch_nested_value' do
      let(:val1) { 2020 }
      let(:val2) { 2021 }
      let(:doc_ref) { FHIR::DocumentReference.new(date: val1, context:) }
      let(:context) { FHIR::DocumentReference::Context.new(period:) }
      let(:period) { FHIR::Period.new(start: val2) }

      it 'fetches a non-nested field' do
        expect(client.fetch_nested_value(doc_ref, 'date')).to eq(val1)
      end

      it 'fetches a nested field' do
        expect(client.fetch_nested_value(doc_ref, 'context.period.start')).to eq(val2)
      end

      it 'returns nil for a non-existent field' do
        expect(client.fetch_nested_value(doc_ref, 'start')).to be_nil
        expect(client.fetch_nested_value(doc_ref, 'context.start')).to be_nil
      end
    end

    describe 'Bundle pagination' do
      context 'when the requested page is within the available entries' do
        it 'returns the correct block of entries for page 1 with page size 2' do
          page_size = 2
          page_num = 1
          result = client.paginate_bundle_entries(entries, page_size, page_num)
          expect(result).to eq(['Entry 1', 'Entry 2'])
        end

        it 'returns the correct block of entries for page 2 with page size 2' do
          page_size = 2
          page_num = 2
          result = client.paginate_bundle_entries(entries, page_size, page_num)
          expect(result).to eq(['Entry 3', 'Entry 4'])
        end

        it 'returns the correct block of entries for page 3 with page size 2' do
          page_size = 2
          page_num = 3
          result = client.paginate_bundle_entries(entries, page_size, page_num)
          expect(result).to eq(['Entry 5'])
        end

        it 'returns the correct block of entries for page 1 with page size 3' do
          page_size = 3
          page_num = 1
          result = client.paginate_bundle_entries(entries, page_size, page_num)
          expect(result).to eq(['Entry 1', 'Entry 2', 'Entry 3'])
        end
      end

      context 'when the requested page exceeds the available entries' do
        it 'returns an empty array for page 4 with page size 2' do
          page_size = 2
          page_num = 4
          result = client.paginate_bundle_entries(entries, page_size, page_num)
          expect(result).to eq([])
        end

        it 'returns an empty array for page 2 with page size 5' do
          page_size = 5
          page_num = 2
          result = client.paginate_bundle_entries(entries, page_size, page_num)
          expect(result).to eq([])
        end
      end

      context 'when the entries array is empty' do
        it 'returns an empty array for any page and page size' do
          page_size = 3
          page_num = 1
          result = client.paginate_bundle_entries([], page_size, page_num)
          expect(result).to eq([])
        end
      end
    end

    describe '#handle_api_errors' do
      context 'when response is successful' do
        let(:result) { OpenStruct.new(code: 200) }

        it 'does not raise an exception' do
          expect { client.handle_api_errors(result) }.not_to raise_error
        end
      end

      context 'when response is an error' do
        let(:result) { OpenStruct.new(code: 400, body: { issue: [{ diagnostics: 'Error Message' }] }.to_json) }

        it 'raises a BackendServiceException' do
          expect { client.handle_api_errors(result) }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end

      context 'when diagnostics are missing in the response' do
        let(:result) { OpenStruct.new(code: 400, body: {}.to_json) }

        it 'handles missing diagnostics gracefully' do
          expect { client.handle_api_errors(result) }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  context 'when the patient is not found', :vcr do
    it 'returns :patient_not_found for 202 response', :vcr do
      VCR.use_cassette 'mr_client/session' do
        VCR.use_cassette 'mr_client/get_a_patient_by_identifier_not_found' do
          partial_client = MedicalRecords::Client.new(session: { user_uuid: '12345',
                                                                 user_id: '22406991' }, icn: '1013868614V792025')
          partial_client.authenticate

          VCR.use_cassette 'mr_client/get_a_list_of_allergies' do
            result = partial_client.list_allergies('uuid')
            expect(result).to eq(:patient_not_found)
          end
        end
      end
    end
  end

  describe '#fhir_search' do
    let(:client) { MedicalRecords::Client.new(session: { user_id: 'test' }, icn: 'test') }
    let(:fhir_model) { FHIR::AllergyIntolerance }
    let(:search_params) do
      {
        search: {
          parameters: {
            patient: 'patient-123',
            'clinical-status': 'active'
          }
        }
      }
    end
    let(:mock_fhir_client) { double('FHIR::Client') }
    let(:first_bundle) { FHIR::Bundle.new(entry: [entry1, entry2], next_link: 'https://example.com/fhir?_getpages=abc&_getpagesoffset=1') }
    let(:second_bundle) { FHIR::Bundle.new(entry: [entry3]) }
    let(:entry1) { FHIR::Bundle::Entry.new(resource: FHIR::AllergyIntolerance.new(id: '1')) }
    let(:entry2) { FHIR::Bundle::Entry.new(resource: FHIR::AllergyIntolerance.new(id: '2')) }
    let(:entry3) { FHIR::Bundle::Entry.new(resource: FHIR::AllergyIntolerance.new(id: '3')) }

    before do
      allow(client).to receive_messages(
        fhir_client: mock_fhir_client,
        default_headers: { 'Cache-Control' => 'no-cache' },
        rewrite_next_link: nil
      )
      allow(client).to receive(:handle_api_errors).and_raise(Common::Exceptions::BackendServiceException.new(400,
                                                                                                             'Error'))
      MedicalRecords::Client.send(:public, *MedicalRecords::Client.protected_instance_methods)
    end

    after do
      MedicalRecords::Client.send(:protected, *MedicalRecords::Client.protected_instance_methods)
    end

    context 'when there is only one page of results' do
      let(:first_reply) { double('FHIR::ClientReply', resource: first_bundle) }

      before do
        allow(client).to receive(:fhir_search_query).and_return(first_reply)
        allow(first_bundle).to receive(:next_link).and_return(nil)
      end

      it 'returns the single bundle without pagination' do
        result = client.fhir_search(fhir_model, search_params)

        expect(client).to have_received(:fhir_search_query).with(fhir_model, search_params)
        expect(client).to have_received(:rewrite_next_link).with(first_bundle)
        expect(result).to eq(first_bundle)
        expect(result.entry.length).to eq(2)
      end
    end

    context 'when there are multiple pages of results' do
      let(:first_reply) { double('FHIR::ClientReply', resource: first_bundle) }
      let(:second_reply) { double('FHIR::ClientReply', resource: second_bundle) }
      let(:next_link) { 'https://example.com/fhir?_getpages=abc&_getpagesoffset=1' }

      before do
        allow(client).to receive(:fhir_search_query).and_return(first_reply)

        # First call to next_link returns the link, second call returns nil
        allow(first_bundle).to receive(:next_link).and_return(next_link)
        allow(second_bundle).to receive(:next_link).and_return(nil)

        allow(mock_fhir_client).to receive(:next_page)
          .with(first_reply, headers: { 'Cache-Control' => 'no-cache' })
          .and_return(second_reply)

        allow(client).to receive(:merge_bundles)
          .with(first_bundle, second_bundle)
          .and_return(FHIR::Bundle.new(entry: [entry1, entry2, entry3]))
      end

      context 'when retry feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_retry_next_page).and_return(false)
        end

        it 'fetches all pages and merges them into a single bundle' do
          result = client.fhir_search(fhir_model, search_params)

          expect(client).to have_received(:fhir_search_query).with(fhir_model, search_params)
          expect(client).to have_received(:rewrite_next_link).with(first_bundle)
          expect(client).to have_received(:rewrite_next_link).with(second_bundle)
          expect(mock_fhir_client).to have_received(:next_page)
            .with(first_reply, headers: { 'Cache-Control' => 'no-cache' })
          expect(client).to have_received(:merge_bundles).with(first_bundle, second_bundle)
          expect(result.entry.length).to eq(3)
        end

        it 'handles API errors on next page requests' do
          error_reply = double('FHIR::ClientReply', resource: nil)
          allow(mock_fhir_client).to receive(:next_page).and_return(error_reply)

          expect { client.fhir_search(fhir_model, search_params) }.to raise_error(Common::Exceptions::BackendServiceException)
          expect(client).to have_received(:handle_api_errors).with(error_reply)
        end
      end

      context 'when retry feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_retry_next_page).and_return(true)
          allow(client).to receive(:with_retries).and_yield.and_return(second_reply)
        end

        it 'uses retries when fetching next pages' do
          result = client.fhir_search(fhir_model, search_params)

          expect(client).to have_received(:with_retries).with(fhir_model)
          expect(mock_fhir_client).to have_received(:next_page)
            .with(first_reply, headers: { 'Cache-Control' => 'no-cache' })
          expect(result.entry.length).to eq(3)
        end

        it 'handles API errors with retries on next page requests' do
          error_reply = double('FHIR::ClientReply', resource: nil)
          # Override the parent context setup for this specific test
          allow(mock_fhir_client).to receive(:next_page).and_return(error_reply)
          allow(client).to receive(:merge_bundles)
          allow(client).to receive(:with_retries).and_yield.and_return(error_reply)

          expect { client.fhir_search(fhir_model, search_params) }.to raise_error(Common::Exceptions::BackendServiceException)
          expect(client).to have_received(:handle_api_errors).with(error_reply)
        end
      end
    end

    context 'when there are three pages of results' do
      let(:first_reply) { double('FHIR::ClientReply', resource: first_bundle) }
      let(:second_reply) { double('FHIR::ClientReply', resource: second_bundle) }
      let(:third_bundle) { FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::AllergyIntolerance.new(id: '4'))]) }
      let(:third_reply) { double('FHIR::ClientReply', resource: third_bundle) }

      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_retry_next_page).and_return(false)
        allow(client).to receive(:fhir_search_query).and_return(first_reply)

        # Configure next_link behavior for pagination
        allow(first_bundle).to receive(:next_link).and_return('page2_link')
        allow(second_bundle).to receive(:next_link).and_return('page3_link')
        allow(third_bundle).to receive(:next_link).and_return(nil)

        allow(mock_fhir_client).to receive(:next_page)
          .with(first_reply, headers: { 'Cache-Control' => 'no-cache' })
          .and_return(second_reply)
        allow(mock_fhir_client).to receive(:next_page)
          .with(second_reply, headers: { 'Cache-Control' => 'no-cache' })
          .and_return(third_reply)

        # Mock merge_bundles to return progressively larger bundles
        intermediate_bundle = FHIR::Bundle.new(entry: [entry1, entry2, entry3])
        end_bundle = FHIR::Bundle.new(entry: [entry1, entry2, entry3,
                                              FHIR::Bundle::Entry.new(resource: FHIR::AllergyIntolerance.new(id: '4'))])

        allow(client).to receive(:merge_bundles)
          .with(first_bundle, second_bundle)
          .and_return(intermediate_bundle)
        allow(client).to receive(:merge_bundles)
          .with(intermediate_bundle, third_bundle)
          .and_return(end_bundle)
      end

      it 'fetches all three pages and merges them sequentially' do
        result = client.fhir_search(fhir_model, search_params)

        expect(mock_fhir_client).to have_received(:next_page).twice
        expect(client).to have_received(:merge_bundles).twice
        expect(client).to have_received(:rewrite_next_link).exactly(3).times
        expect(result.entry.length).to eq(4)
      end
    end

    context 'when the initial search query fails' do
      before do
        # Override the parent context setup and make fhir_search_query raise an exception directly
        allow(client).to receive(:handle_api_errors).and_call_original
        allow(client).to receive(:fhir_search_query).and_raise(Common::Exceptions::BackendServiceException.new(400,
                                                                                                               'Error'))
      end

      it 'handles API errors from the initial query' do
        expect { client.fhir_search(fhir_model, search_params) }.to raise_error(Common::Exceptions::BackendServiceException)

        expect(client).to have_received(:fhir_search_query).with(fhir_model, search_params)
      end
    end
  end

  describe '#rewrite_next_link' do
    let(:client) { MedicalRecords::Client.new(session: { user_id: 'test' }, icn: 'test') }

    it 'rewrites full URL to relative path for /v1/fhir' do
      next_url = 'https://example.org/v1/fhir?_getpages=abc&_getpagesoffset=1&_count=2'
      bundle = FHIR::Bundle.new(
        link: [FHIR::Bundle::Link.new(relation: 'next', url: next_url)]
      )
      allow(client).to receive(:base_path).and_return('https://fwdproxy.va.gov/v1/fhir/')
      client.send(:rewrite_next_link, bundle)

      expect(bundle.link.find { |l| l.relation == 'next' }.url)
        .to eq('https://fwdproxy.va.gov/v1/fhir?_getpages=abc&_getpagesoffset=1&_count=2')
    end

    it 'rewrites full URL to relative path for /fhir' do
      next_url = 'https://example.org/fhir?_getpages=xyz&_count=1'
      bundle = FHIR::Bundle.new(
        link: [FHIR::Bundle::Link.new(relation: 'next', url: next_url)]
      )
      allow(client).to receive(:base_path).and_return('https://fwdproxy.va.gov/fhir/')
      client.send(:rewrite_next_link, bundle)

      expect(bundle.link.find { |l| l.relation == 'next' }.url)
        .to eq('https://fwdproxy.va.gov/fhir?_getpages=xyz&_count=1')
    end
  end

  def extract_date(resource)
    case resource
    when FHIR::DiagnosticReport
      resource.effectiveDateTime.to_i
    when FHIR::DocumentReference
      resource.date.to_i
    else
      0
    end
  end
end
