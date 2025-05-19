# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client'
require 'stringio'

describe MedicalRecords::Client do
  context 'using API Gateway endpoints' do
    context 'when a valid session exists', :vcr do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)

        VCR.use_cassette('user_eligibility_client/apigw_perform_an_eligibility_check_for_premium_user',
                         match_requests_on: %i[method sm_user_ignoring_path_param]) do
          VCR.use_cassette 'mr_client/apigw_session' do
            VCR.use_cassette 'mr_client/apigw_get_a_patient_by_identifier' do
              @client ||= begin
                client = MedicalRecords::Client.new(session: { user_id: '22406991', icn: '1013868614V792025' })
                client.authenticate
                client
              end
            end
          end
        end

        MedicalRecords::Client.send(:public, *MedicalRecords::Client.protected_instance_methods)

        # Redirect FHIR logger's output to the buffer before each test
        @original_output = FHIR.logger.instance_variable_get(:@logdev).dev
        FHIR.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(info_log_buffer))
      end

      after do
        MedicalRecords::Client.send(:protected, *MedicalRecords::Client.protected_instance_methods)

        # Restore original logger output after each test
        FHIR.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(@original_output))
      end

      let(:client) { @client }
      let(:entries) { ['Entry 1', 'Entry 2', 'Entry 3', 'Entry 4', 'Entry 5'] }
      let(:info_log_buffer) { StringIO.new }

      it 'gets a list of allergies', :vcr do
        VCR.use_cassette 'mr_client/apigw_get_a_list_of_allergies' do
          allergy_list = client.list_allergies
          expect(
            a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
          ).to have_been_made.at_least_once
          expect(allergy_list).to be_a(FHIR::Bundle)
          expect(info_log_buffer.string).not_to include('2952')
          # Verify that the list is sorted reverse chronologically (with nil values to the end).
          allergy_list.entry.each_cons(2) do |prev, curr|
            prev_date = prev.resource.recordedDate
            curr_date = curr.resource.recordedDate
            expect(curr_date.nil? || prev_date >= curr_date).to be true
          end
        end
      end
    end
  end

  context 'using legacy endpoints' do
    context 'when a valid session exists', :vcr do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_support_new_model_health_condition).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_support_new_model_vaccine).and_return(false)

        VCR.use_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                         match_requests_on: %i[method sm_user_ignoring_path_param]) do
          VCR.use_cassette 'mr_client/session' do
            VCR.use_cassette 'mr_client/get_a_patient_by_identifier' do
              @client ||= begin
                client = MedicalRecords::Client.new(session: { user_id: '22406991', icn: '1013868614V792025' })
                client.authenticate
                client
              end
            end
          end
        end

        MedicalRecords::Client.send(:public, *MedicalRecords::Client.protected_instance_methods)

        # Redirect FHIR logger's output to the buffer before each test
        @original_output = FHIR.logger.instance_variable_get(:@logdev).dev
        FHIR.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(info_log_buffer))
      end

      after do
        MedicalRecords::Client.send(:protected, *MedicalRecords::Client.protected_instance_methods)

        # Restore original logger output after each test
        FHIR.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(@original_output))
      end

      let(:client) { @client }
      let(:entries) { ['Entry 1', 'Entry 2', 'Entry 3', 'Entry 4', 'Entry 5'] }
      let(:info_log_buffer) { StringIO.new }

      context 'when new-model flipper flags are enabled' do
        let(:user_uuid)    { 'user-123' }
        let(:vac_key)      { "#{user_uuid}-vaccines" }
        let(:cond_key)     { "#{user_uuid}-conditions" }
        let(:fake_bundle)  { double('FHIR::Bundle', entry: []) }

        before do
          allow(Flipper).to receive(:enabled?)
            .with(:mhv_medical_records_support_new_model_health_condition).and_return(true)
          allow(Flipper).to receive(:enabled?)
            .with(:mhv_medical_records_support_new_model_vaccine).and_return(true)
        end

        describe '#list_vaccines' do
          it 'gets a list of vaccines', :vcr do
            VCR.use_cassette 'mr_client/get_a_list_of_vaccines' do
              vaccine_list = client.list_vaccines('uuid')
              expect(vaccine_list).to be_a(Vets::Collection)
              expect(
                a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
              ).to have_been_made.at_least_once
            end
          end

          context 'when cache is present' do
            let(:cached_records) { [double('v1'), double('v2')] }
            let(:fake_collection) { double('Vets::Collection', records: cached_records) }

            before do
              allow(MHV::MR::Vaccine).to receive(:get_cached).with(vac_key).and_return(cached_records)
              allow(client).to receive(:fhir_search)
              allow(Vets::Collection).to receive(:new)
                .with(cached_records, MHV::MR::Vaccine)
                .and_return(fake_collection)
            end

            it 'returns a Vets::Collection built from the cache and does not call FHIR' do
              coll = client.list_vaccines(user_uuid)
              expect(coll).to eq(fake_collection)
              expect(client).not_to have_received(:fhir_search)
            end
          end

          context 'when cache is empty' do
            let(:fetched_resources) { [double('r1'), double('r2')] }
            let(:vaccine_objs)      { [double('v1'), double('v2')] }
            let(:fake_collection)   { double('Vets::Collection', records: vaccine_objs) }

            before do
              allow(MHV::MR::Vaccine).to receive(:get_cached).with(vac_key).and_return(nil)
              allow(client).to receive(:fhir_search).and_return(fake_bundle)
              # simulate from_fhir on each entry
              allow(fake_bundle).to receive(:entry).and_return(fetched_resources.map { |r| double(resource: r) })
              allow(MHV::MR::Vaccine).to receive(:from_fhir).and_return(*vaccine_objs)
              allow(MHV::MR::Vaccine).to receive(:set_cached)

              allow(Vets::Collection).to receive(:new)
                .with(vaccine_objs, MHV::MR::Vaccine)
                .and_return(fake_collection)
            end

            it 'fetches via FHIR, wraps in Vets::Collection and writes to cache' do
              coll = client.list_vaccines(user_uuid)
              expect(client).to have_received(:fhir_search).with(
                FHIR::Immunization,
                search: hash_including(parameters: hash_including(patient: anything))
              )
              expect(MHV::MR::Vaccine).to have_received(:set_cached).with(vac_key, vaccine_objs)
              expect(coll).to eq(fake_collection)
            end
          end
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
          let(:cond_key) { "#{user_uuid}-conditions" }

          it 'gets a list of health conditions', :vcr do
            VCR.use_cassette 'mr_client/get_a_list_of_health_conditions' do
              condition_list = client.list_conditions('uuid')
              expect(condition_list).to be_a(Vets::Collection)
              expect(
                a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
              ).to have_been_made.at_least_once
            end
          end

          context 'when cache is present' do
            let(:cached_records) { [double('c1'), double('c2')] }
            let(:fake_collection) { double('Vets::Collection', records: cached_records) }

            before do
              allow(MHV::MR::HealthCondition).to receive(:get_cached).with(cond_key).and_return(cached_records)
              allow(client).to receive(:fhir_search)
              allow(Vets::Collection).to receive(:new)
                .with(cached_records, MHV::MR::HealthCondition)
                .and_return(fake_collection)
            end

            it 'returns a Vets::Collection built from the cache and does not call FHIR' do
              coll = client.list_conditions(user_uuid)
              expect(coll).to eq(fake_collection)
              expect(client).not_to have_received(:fhir_search)
            end
          end

          context 'when cache is empty' do
            let(:fetched_resources) { [double('r1'), double('r2')] }
            let(:condition_objs)    { [double('c1'), double('c2')] }
            let(:fake_collection)   { double('Vets::Collection', records: condition_objs) }

            before do
              allow(MHV::MR::HealthCondition).to receive(:get_cached).with(cond_key).and_return(nil)
              allow(client).to receive(:fhir_search).and_return(fake_bundle)
              allow(fake_bundle).to receive(:entry)
                .and_return(fetched_resources.map { |r| double(resource: r) })
              allow(MHV::MR::HealthCondition).to receive(:from_fhir).and_return(*condition_objs)
              allow(MHV::MR::HealthCondition).to receive(:set_cached)
              allow(Vets::Collection).to receive(:new)
                .with(condition_objs, MHV::MR::HealthCondition)
                .and_return(fake_collection)
            end

            it 'fetches via FHIR, wraps in Vets::Collection and writes to cache' do
              coll = client.list_conditions(user_uuid)
              expect(client).to have_received(:fhir_search).with(
                FHIR::Condition,
                search: hash_including(parameters: hash_including(patient: anything))
              )
              expect(MHV::MR::HealthCondition).to have_received(:set_cached).with(cond_key, condition_objs)
              expect(coll).to eq(fake_collection)
            end
          end
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

        context 'when the redaction feature toggle is enabled', :vcr do
          before do
            Flipper.enable(:mhv_medical_records_redact_fhir_client_logs)
          end

          it 'gets a patient by identifer', :vcr do
            VCR.use_cassette 'mr_client/get_a_patient_by_identifier' do
              patient_bundle = client.get_patient_by_identifier(client.fhir_client, patient_id)
              expect(patient_bundle).to be_a(FHIR::Bundle)
              expect(patient_bundle.entry[0].resource).to be_a(FHIR::Patient)
              expect(patient_bundle.entry[0].resource.id).to eq('2952')
              expect(info_log_buffer.string).not_to include(patient_id.to_s)
            end
          end
        end

        context 'when the redaction feature toggle is disabled', :vcr do
          before do
            Flipper.disable(:mhv_medical_records_redact_fhir_client_logs)
          end

          it 'gets a patient by identifer', :vcr do
            VCR.use_cassette 'mr_client/get_a_patient_by_identifier' do
              client.get_patient_by_identifier(client.fhir_client, patient_id)
              expect(info_log_buffer.string).to include(patient_id.to_s)
            end
          end
        end
      end

      it 'gets a list of allergies', :vcr do
        VCR.use_cassette 'mr_client/get_a_list_of_allergies' do
          allergy_list = client.list_allergies
          expect(
            a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
          ).to have_been_made.at_least_once
          expect(allergy_list).to be_a(FHIR::Bundle)
          expect(info_log_buffer.string).not_to include('2952')
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
          expect(info_log_buffer.string).not_to include(allergy_id.to_s)
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
          allergies_list = client.list_allergies
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
        VCR.use_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                         match_requests_on: %i[method sm_user_ignoring_path_param]) do
          VCR.use_cassette 'mr_client/session' do
            VCR.use_cassette 'mr_client/get_a_patient_by_identifier_not_found' do
              allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

              partial_client = MedicalRecords::Client.new(session: {
                                                            user_id: '22406991',
                                                            icn: '1013868614V792025'
                                                          })
              partial_client.authenticate

              VCR.use_cassette 'mr_client/get_a_list_of_allergies' do
                result = partial_client.list_allergies
                expect(result).to eq(:patient_not_found)
              end
            end
          end
        end
      end
    end

    describe '#rewrite_next_link' do
      let(:client) { MedicalRecords::Client.new(session: { user_id: 'test', icn: 'test' }) }

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
end
