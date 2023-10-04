# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client'

describe MedicalRecords::Client do
  before(:all) do
    VCR.use_cassette 'mr_client/session', record: :new_episodes do
      VCR.use_cassette 'mr_client/get_a_patient_by_identifier', record: :new_episodes do
        @client ||= begin
          client = MedicalRecords::Client.new(session: { user_id: '22406991', icn: '1013868614V792025' })
          client.authenticate
          client
        end
      end
    end
  end

  before do
    MedicalRecords::Client.send(:public, *MedicalRecords::Client.protected_instance_methods)
  end

  after do
    MedicalRecords::Client.send(:protected, *MedicalRecords::Client.protected_instance_methods)
  end

  let(:client) { @client }
  let(:entries) { ['Entry 1', 'Entry 2', 'Entry 3', 'Entry 4', 'Entry 5'] }

  it 'gets a patient by identifer', :vcr do
    VCR.use_cassette 'mr_client/get_a_patient_by_identifier' do
      patient_bundle = client.get_patient_by_identifier(client.fhir_client, 12_345)
      expect(patient_bundle).to be_a(FHIR::Bundle)
      expect(patient_bundle.entry[0].resource).to be_a(FHIR::Patient)
      expect(patient_bundle.entry[0].resource.id).to eq('2952')
    end
  end

  it 'gets a list of vaccines', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_vaccines' do
      vaccine_list = client.list_vaccines
      expect(vaccine_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a single vaccine', :vcr do
    VCR.use_cassette 'mr_client/get_a_vaccine' do
      vaccine_list = client.get_vaccine(2_954)
      expect(vaccine_list).to be_a(FHIR::Immunization)
    end
  end

  it 'gets a list of chem/hem labs', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_chemhem_labs' do
      chemhem_list = client.list_labs_chemhem_diagnostic_report
      expect(chemhem_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a list of other DiagnosticReport labs', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_diagreport_labs' do
      other_lab_list = client.list_labs_other_diagnostic_report
      expect(other_lab_list).to be_a(FHIR::Bundle)
    end
  end

  it 'gets a list of other DocumentReference labs', :vcr do
    VCR.use_cassette 'mr_client/get_a_list_of_docref_labs' do
      lab_doc_list = client.list_labs_document_reference
      expect(lab_doc_list).to be_a(FHIR::Bundle)
    end
  end

  it 'combines the lab results', :vcr do
    VCR.use_cassette('mr_client/get_a_list_of_chemhem_labs') do
      VCR.use_cassette('mr_client/get_a_list_of_diagreport_labs') do
        VCR.use_cassette('mr_client/get_a_list_of_docref_labs') do
          combined_labs_bundle = client.list_labs_and_tests
          expect(combined_labs_bundle).to be_a(FHIR::Bundle)
          expect(combined_labs_bundle.total).to eq(5)
          expect(combined_labs_bundle.entry.count { |entry| entry.is_a?(FHIR::DiagnosticReport) }).to eq(3)
          expect(combined_labs_bundle.entry.count { |entry| entry.is_a?(FHIR::DocumentReference) }).to eq(2)

          # Ensure all entries are sorted in reverse chronological order
          combined_labs_bundle.entry.each_cons(2) do |prev, curr|
            prev_date = extract_date(prev)
            curr_date = extract_date(curr)
            expect(prev_date).to be >= curr_date
          end
        end
      end
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

  describe 'Bundle sorting' do
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
        it 'places the entry with the missing field at the beginning' do
          sorted = client.sort_bundle(bundle_with_missing_field, :onsetDateTime, :desc)
          expect(sorted.entry.first.resource.onsetDateTime).to be_nil
        end
      end
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

  def extract_date(resource)
    case resource
    when FHIR::DiagnosticReport
      resource.effectiveDateTime&.to_i || 0
    when FHIR::DocumentReference
      resource.date&.to_i || 0
    else
      0
    end
  end
end
