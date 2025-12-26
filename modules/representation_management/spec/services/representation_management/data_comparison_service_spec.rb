# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::DataComparisonService do
  let(:service) { described_class.new }
  let(:mock_github_client) { instance_double(Octokit::Client) }
  let(:mock_file_info) { double('file_info', download_url: 'https://raw.githubusercontent.com/test/file.xlsx') }

  before do
    # Suppress puts output in tests
    allow(service).to receive(:puts)
  end

  describe '#run' do
    let(:file_individuals) { Set.new(%w[12345 67890 11111]) }
    let(:file_orgs) { Set.new(%w[A1Q B2R]) }
    let(:file_data) { { individuals: file_individuals, organizations: file_orgs } }
    let(:db_data) do
      {
        veteran_reps: Set.new(%w[12345 99999]),
        accredited_individuals: Set.new(%w[12345 67890]),
        veteran_orgs: Set.new(['A1Q']),
        accredited_orgs: Set.new(%w[A1Q C3S])
      }
    end

    context 'when successful' do
      before do
        allow(service).to receive_messages(
          download_file: 'fake_xlsx_content',
          extract_identifiers_from_file: file_data,
          query_database_models: db_data
        )
      end

      it 'completes without error' do
        expect { service.run }.not_to raise_error
      end

      it 'calls all major steps in order' do
        expect(service).to receive(:fetch_and_validate_file).ordered.and_call_original
        expect(service).to receive(:extract_and_report_file_data).ordered.and_call_original
        expect(service).to receive(:query_and_report_database_data).ordered.and_call_original
        expect(service).to receive(:compare_and_report).ordered.and_call_original

        service.run
      end

      it 'stores comparison results in @results instance variable' do
        service.run
        results = service.instance_variable_get(:@results)

        expect(results).to have_key(:file_vs_veteran_rep)
        expect(results).to have_key(:file_vs_accredited_ind)
        expect(results).to have_key(:file_vs_veteran_org)
        expect(results).to have_key(:file_vs_accredited_org)
      end

      it 'prints completion message with elapsed time' do
        expect(service).to receive(:print_completion)
        service.run
      end
    end

    context 'when download fails' do
      before do
        allow(service).to receive(:download_file).and_return(nil)
      end

      it 'exits early without proceeding to extraction' do
        expect(service).not_to receive(:extract_identifiers_from_file)
        service.run
      end

      it 'does not perform database queries' do
        expect(service).not_to receive(:query_database_models)
        service.run
      end
    end

    context 'when an error occurs during fetch' do
      let(:error) { StandardError.new('Network error') }

      before do
        allow(service).to receive(:fetch_and_validate_file).and_raise(error)
      end

      it 'handles the error gracefully' do
        expect(service).to receive(:handle_error).with(error)
        service.run
      end

      it 'does not raise the error to the caller' do
        expect { service.run }.not_to raise_error
      end
    end

    context 'when an error occurs during extraction' do
      let(:error) { StandardError.new('Excel parsing error') }

      before do
        allow(service).to receive(:download_file).and_return('fake_content')
        allow(service).to receive(:extract_identifiers_from_file).and_raise(error)
      end

      it 'handles the error and prints error details' do
        expect(service).to receive(:handle_error).with(error)
        service.run
      end
    end
  end

  describe '#download_file' do
    before do
      xlsx_file_fetcher = double('xlsx_file_fetcher', github_access_token: 'fake_github_token')
      allow(Settings).to receive(:xlsx_file_fetcher).and_return(xlsx_file_fetcher)
      allow(Octokit::Client).to receive(:new).with(access_token: 'fake_github_token')
                                             .and_return(mock_github_client)
      allow(mock_github_client).to receive(:contents)
        .with('department-of-veterans-affairs/va.gov-team-sensitive',
              path: 'products/accredited-representation-management/data/rep-org-addresses.xlsx')
        .and_return(mock_file_info)
    end

    context 'when GitHub API and HTTP request succeed' do
      before do
        stub_request(:get, 'https://raw.githubusercontent.com/test/file.xlsx')
          .to_return(status: 200, body: 'excel_file_content')
      end

      it 'returns file content' do
        result = service.send(:download_file)
        expect(result).to eq('excel_file_content')
      end

      it 'sets up GitHub client with correct token' do
        expect(Octokit::Client).to receive(:new).with(access_token: 'fake_github_token')
        service.send(:download_file)
      end
    end

    context 'when HTTP request fails' do
      before do
        allow(service).to receive(:setup_github_client)
        allow(service).to receive(:fetch_github_file_info).and_return(mock_file_info)
        allow(service).to receive(:fetch_file_content).and_raise(StandardError.new('HTTP request failed'))
      end

      it 'returns nil' do
        result = service.send(:download_file)
        expect(result).to be_nil
      end

      it 'outputs error message' do
        expect(service).to receive(:puts).with(/ERROR: Failed to download file/)
        service.send(:download_file)
      end
    end

    context 'when GitHub API raises an error' do
      before do
        allow(mock_github_client).to receive(:contents).and_raise(Octokit::NotFound.new)
      end

      it 'returns nil' do
        result = service.send(:download_file)
        expect(result).to be_nil
      end

      it 'outputs error details' do
        expect(service).to receive(:puts).with(/ERROR: Failed to download file/)
        service.send(:download_file)
      end
    end
  end

  describe '#extract_identifiers_from_file' do
    let(:mock_xlsx) { instance_double(Roo::Excelx) }
    let(:mock_attorneys_sheet) { double('attorneys_sheet') }
    let(:mock_agents_sheet) { double('agents_sheet') }
    let(:mock_reps_sheet) { double('representatives_sheet') }
    let(:mock_vsos_sheet) { double('vsos_sheet') }

    before do
      allow(Roo::Spreadsheet).to receive(:open).and_return(mock_xlsx)
      allow(mock_xlsx).to receive(:sheets).and_return(%w[Attorneys Agents Representatives VSOs])
    end

    context 'with all sheets present and valid' do
      before do
        # Mock Attorneys sheet
        allow(mock_xlsx).to receive(:sheet).with('Attorneys').and_return(mock_attorneys_sheet)
        allow(mock_attorneys_sheet).to receive(:row).with(1).and_return(%w[Number Name Address])
        allow(mock_attorneys_sheet).to receive(:last_row).and_return(3)
        allow(mock_attorneys_sheet).to receive(:row).with(2).and_return(['11111', 'John Attorney', '123 Main'])
        allow(mock_attorneys_sheet).to receive(:row).with(3).and_return(['22222', 'Jane Attorney', '456 Oak'])

        # Mock Agents sheet
        allow(mock_xlsx).to receive(:sheet).with('Agents').and_return(mock_agents_sheet)
        allow(mock_agents_sheet).to receive(:row).with(1).and_return(%w[Number Name])
        allow(mock_agents_sheet).to receive(:last_row).and_return(2)
        allow(mock_agents_sheet).to receive(:row).with(2).and_return(['33333', 'Bob Agent'])

        # Mock Representatives sheet
        allow(mock_xlsx).to receive(:sheet).with('Representatives').and_return(mock_reps_sheet)
        allow(mock_reps_sheet).to receive(:row).with(1).and_return(%w[Number Name])
        allow(mock_reps_sheet).to receive(:last_row).and_return(2)
        allow(mock_reps_sheet).to receive(:row).with(2).and_return(['44444', 'Alice Rep'])

        # Mock VSOs sheet
        allow(mock_xlsx).to receive(:sheet).with('VSOs').and_return(mock_vsos_sheet)
        allow(mock_vsos_sheet).to receive(:row).with(1).and_return(%w[POA Name])
        allow(mock_vsos_sheet).to receive(:last_row).and_return(3)
        allow(mock_vsos_sheet).to receive(:row).with(2).and_return(['A1Q', 'Veterans Org Alpha'])
        allow(mock_vsos_sheet).to receive(:row).with(3).and_return(['b2r', 'Veterans Org Beta'])
      end

      it 'extracts individuals and organizations into Sets' do
        result = service.send(:extract_identifiers_from_file, 'fake_content')

        expect(result[:individuals]).to be_a(Set)
        expect(result[:organizations]).to be_a(Set)
      end

      it 'extracts all individual registration numbers' do
        result = service.send(:extract_identifiers_from_file, 'fake_content')

        expect(result[:individuals]).to include('11111', '22222', '33333', '44444')
        expect(result[:individuals].size).to eq(4)
      end

      it 'extracts all organization POA codes' do
        result = service.send(:extract_identifiers_from_file, 'fake_content')

        expect(result[:organizations]).to include('A1Q', 'B2R')
        expect(result[:organizations].size).to eq(2)
      end

      it 'normalizes organization POA codes to uppercase' do
        result = service.send(:extract_identifiers_from_file, 'fake_content')

        expect(result[:organizations]).to include('B2R')
        expect(result[:organizations]).not_to include('b2r')
      end

      it 'converts all numbers to strings' do
        result = service.send(:extract_identifiers_from_file, 'fake_content')

        expect(result[:individuals]).to all(be_a(String))
      end
    end

    context 'with duplicate registration numbers' do
      before do
        allow(mock_xlsx).to receive(:sheet).with('Attorneys').and_return(mock_attorneys_sheet)
        allow(mock_attorneys_sheet).to receive(:row).with(1).and_return(['Number'])
        allow(mock_attorneys_sheet).to receive(:last_row).and_return(3)
        allow(mock_attorneys_sheet).to receive(:row).with(2).and_return(['12345'])
        allow(mock_attorneys_sheet).to receive(:row).with(3).and_return(['12345'])

        allow(mock_xlsx).to receive(:sheets).and_return(['Attorneys'])
      end

      it 'stores each unique number only once' do
        result = service.send(:extract_identifiers_from_file, 'fake_content')

        expect(result[:individuals]).to eq(Set.new(['12345']))
        expect(result[:individuals].size).to eq(1)
      end
    end
  end

  describe '#query_database_models' do
    let!(:rep1) { create(:representative, representative_id: '11111') }
    let!(:rep2) { create(:representative, representative_id: '22222') }
    let!(:ind1) { create(:accredited_individual, registration_number: '33333') }
    let!(:ind2) { create(:accredited_individual, registration_number: '44444') }
    let!(:org1) { create(:organization, poa: 'A1Q') }
    let!(:org2) { create(:organization, poa: 'b2r') }
    let!(:acc_org1) { create(:accredited_organization, poa_code: 'C3S') }
    let!(:acc_org2) { create(:accredited_organization, poa_code: 'd4t') }

    it 'returns a hash with all four model Sets' do
      result = service.send(:query_database_models)

      expect(result).to have_key(:veteran_reps)
      expect(result).to have_key(:accredited_individuals)
      expect(result).to have_key(:veteran_orgs)
      expect(result).to have_key(:accredited_orgs)
    end

    it 'queries Veteran::Service::Representative correctly' do
      result = service.send(:query_database_models)

      expect(result[:veteran_reps]).to be_a(Set)
      expect(result[:veteran_reps]).to include('11111', '22222')
      expect(result[:veteran_reps].size).to eq(2)
    end

    it 'queries AccreditedIndividual correctly' do
      result = service.send(:query_database_models)

      expect(result[:accredited_individuals]).to be_a(Set)
      expect(result[:accredited_individuals]).to include('33333', '44444')
      expect(result[:accredited_individuals].size).to eq(2)
    end

    it 'queries Veteran::Service::Organization with normalized POA codes' do
      result = service.send(:query_database_models)

      expect(result[:veteran_orgs]).to be_a(Set)
      expect(result[:veteran_orgs]).to include('A1Q', 'B2R')
      expect(result[:veteran_orgs].size).to eq(2)
    end

    it 'queries AccreditedOrganization with normalized POA codes' do
      result = service.send(:query_database_models)

      expect(result[:accredited_orgs]).to be_a(Set)
      expect(result[:accredited_orgs]).to include('C3S', 'D4T')
      expect(result[:accredited_orgs].size).to eq(2)
    end

    it 'converts all IDs to strings' do
      result = service.send(:query_database_models)

      expect(result.values).to all(all(be_a(String)))
    end

    it 'uppercases organization POA codes' do
      create(:organization, poa: 'xyz')
      result = service.send(:query_database_models)

      expect(result[:veteran_orgs]).to include('XYZ')
      expect(result[:veteran_orgs]).not_to include('xyz')
    end
  end

  describe '#perform_comparisons' do
    let(:file_data) do
      {
        individuals: Set.new(%w[11111 22222 33333]),
        organizations: Set.new(%w[ABC DEF])
      }
    end

    let(:db_data) do
      {
        veteran_reps: Set.new(%w[11111 44444]),
        accredited_individuals: Set.new(%w[11111 22222]),
        veteran_orgs: Set.new(['ABC']),
        accredited_orgs: Set.new(%w[ABC GHI])
      }
    end

    before do
      service.send(:perform_comparisons, file_data, db_data)
    end

    describe 'file vs Veteran::Service::Representative comparison' do
      it 'identifies individuals in file but not in DB' do
        result = service.instance_variable_get(:@results)[:file_vs_veteran_rep]

        expect(result[:in_file_not_db]).to eq(Set.new(%w[22222 33333]))
      end

      it 'identifies individuals in DB but not in file' do
        result = service.instance_variable_get(:@results)[:file_vs_veteran_rep]

        expect(result[:in_db_not_file]).to eq(Set.new(['44444']))
      end

      it 'identifies individuals in both file and DB' do
        result = service.instance_variable_get(:@results)[:file_vs_veteran_rep]

        expect(result[:in_both]).to eq(Set.new(['11111']))
      end
    end

    describe 'file vs AccreditedIndividual comparison' do
      it 'identifies individuals in file but not in DB' do
        result = service.instance_variable_get(:@results)[:file_vs_accredited_ind]

        expect(result[:in_file_not_db]).to eq(Set.new(['33333']))
      end

      it 'identifies individuals in DB but not in file' do
        result = service.instance_variable_get(:@results)[:file_vs_accredited_ind]

        expect(result[:in_db_not_file]).to be_empty
      end

      it 'identifies individuals in both file and DB' do
        result = service.instance_variable_get(:@results)[:file_vs_accredited_ind]

        expect(result[:in_both]).to eq(Set.new(%w[11111 22222]))
      end
    end

    describe 'file vs Veteran::Service::Organization comparison' do
      it 'identifies organizations in file but not in DB' do
        result = service.instance_variable_get(:@results)[:file_vs_veteran_org]

        expect(result[:in_file_not_db]).to eq(Set.new(['DEF']))
      end

      it 'identifies organizations in DB but not in file' do
        result = service.instance_variable_get(:@results)[:file_vs_veteran_org]

        expect(result[:in_db_not_file]).to be_empty
      end

      it 'identifies organizations in both file and DB' do
        result = service.instance_variable_get(:@results)[:file_vs_veteran_org]

        expect(result[:in_both]).to eq(Set.new(['ABC']))
      end
    end

    describe 'file vs AccreditedOrganization comparison' do
      it 'identifies organizations in file but not in DB' do
        result = service.instance_variable_get(:@results)[:file_vs_accredited_org]

        expect(result[:in_file_not_db]).to eq(Set.new(['DEF']))
      end

      it 'identifies organizations in DB but not in file' do
        result = service.instance_variable_get(:@results)[:file_vs_accredited_org]

        expect(result[:in_db_not_file]).to eq(Set.new(['GHI']))
      end

      it 'identifies organizations in both file and DB' do
        result = service.instance_variable_get(:@results)[:file_vs_accredited_org]

        expect(result[:in_both]).to eq(Set.new(['ABC']))
      end
    end
  end

  describe '#print_results' do
    before do
      service.instance_variable_set(:@results, {
                                      file_vs_veteran_rep: {
                                        in_both: Set.new(['11111']),
                                        in_file_not_db: Set.new(['22222']),
                                        in_db_not_file: Set.new(['33333'])
                                      },
                                      file_vs_accredited_ind: {
                                        in_both: Set.new(['44444']),
                                        in_file_not_db: Set.new,
                                        in_db_not_file: Set.new(['55555'])
                                      },
                                      file_vs_veteran_org: {
                                        in_both: Set.new(['A1Q']),
                                        in_file_not_db: Set.new(['B2R']),
                                        in_db_not_file: Set.new
                                      },
                                      file_vs_accredited_org: {
                                        in_both: Set.new,
                                        in_file_not_db: Set.new(['C3S']),
                                        in_db_not_file: Set.new(['D4T'])
                                      }
                                    })
    end

    it 'prints all four comparison results' do
      expect(service).to receive(:print_individual_comparison)
        .with('File vs Veteran::Service::Representative', anything)
      expect(service).to receive(:print_individual_comparison)
        .with('File vs AccreditedIndividual', anything)
      expect(service).to receive(:print_organization_comparison)
        .with('File vs Veteran::Service::Organization', anything)
      expect(service).to receive(:print_organization_comparison)
        .with('File vs AccreditedOrganization', anything)

      service.send(:print_results)
    end

    it 'does not raise errors' do
      expect { service.send(:print_results) }.not_to raise_error
    end
  end

  describe '#print_individual_comparison' do
    let(:comparison) do
      {
        in_both: Set.new(%w[11111 22222]),
        in_file_not_db: Set.new((1..60).map(&:to_s)),
        in_db_not_file: Set.new(['99999'])
      }
    end

    it 'prints summary counts' do
      expect(service).to receive(:puts).with(/In both: 2/)
      expect(service).to receive(:puts).with(/In file but not in DB: 60/)
      expect(service).to receive(:puts).with(/In DB but not in file: 1/)

      service.send(:print_individual_comparison, 'Test Comparison', comparison)
    end

    it 'limits output to first 50 when more than 50 discrepancies exist' do
      call_count = 0
      allow(service).to receive(:puts) do |msg|
        call_count += 1 if msg.to_s.match?(/^\s{4}\d+$/)
      end

      service.send(:print_individual_comparison, 'Test Comparison', comparison)

      # Should print exactly 50 IDs from in_file_not_db (60 items) + 1 from in_db_not_file
      expect(call_count).to eq(51)
    end

    it 'prints overflow message when more than 50 items' do
      expect(service).to receive(:puts).with(/... \(10 more\)/)

      service.send(:print_individual_comparison, 'Test Comparison', comparison)
    end
  end

  describe '#print_organization_comparison' do
    let(:comparison) do
      {
        in_both: Set.new(%w[A1Q B2R]),
        in_file_not_db: Set.new(%w[C3S D4T]),
        in_db_not_file: Set.new(['E5U'])
      }
    end

    it 'prints summary counts' do
      expect(service).to receive(:puts).with(/In both: 2/)
      expect(service).to receive(:puts).with(/In file but not in DB: 2/)
      expect(service).to receive(:puts).with(/In DB but not in file: 1/)

      service.send(:print_organization_comparison, 'Test Org Comparison', comparison)
    end

    it 'prints all POA codes in file but not DB' do
      expect(service).to receive(:puts).with(/C3S/)
      expect(service).to receive(:puts).with(/D4T/)

      service.send(:print_organization_comparison, 'Test Org Comparison', comparison)
    end

    it 'prints all POA codes in DB but not file' do
      expect(service).to receive(:puts).with(/E5U/)

      service.send(:print_organization_comparison, 'Test Org Comparison', comparison)
    end
  end

  describe 'GitHub constants' do
    it 'has correct GitHub organization constant' do
      expect(described_class::GITHUB_ORG).to eq('department-of-veterans-affairs')
    end

    it 'has correct GitHub repository constant' do
      expect(described_class::GITHUB_REPO).to eq('va.gov-team-sensitive')
    end

    it 'has correct GitHub file path constant' do
      expected_path = 'products/accredited-representation-management/data/rep-org-addresses.xlsx'
      expect(described_class::GITHUB_PATH).to eq(expected_path)
    end
  end

  describe '#handle_error' do
    let(:error) { StandardError.new('Test error message') }

    before do
      allow(error).to receive(:backtrace).and_return(['line 1', 'line 2', 'line 3'])
    end

    it 'outputs error class and message' do
      expect(service).to receive(:puts).with(/ERROR: StandardError: Test error message/)
      service.send(:handle_error, error)
    end

    it 'outputs backtrace' do
      expect(service).to receive(:puts).with(/line 1/)
      service.send(:handle_error, error)
    end

    it 'outputs failure message' do
      expect(service).to receive(:puts).with(/Comparison failed/)
      service.send(:handle_error, error)
    end
  end

  describe 'private helper methods' do
    describe '#setup_github_client' do
      before do
        xlsx_file_fetcher = double('xlsx_file_fetcher', github_access_token: 'test_token_12345')
        allow(Settings).to receive(:xlsx_file_fetcher).and_return(xlsx_file_fetcher)
      end

      it 'creates Octokit client with access token from settings' do
        expect(Octokit::Client).to receive(:new).with(access_token: 'test_token_12345')
        service.send(:setup_github_client)
      end

      it 'stores client in instance variable' do
        allow(Octokit::Client).to receive(:new).and_return(mock_github_client)
        service.send(:setup_github_client)

        expect(service.instance_variable_get(:@github_client)).to eq(mock_github_client)
      end
    end

    describe '#fetch_github_file_info' do
      before do
        service.instance_variable_set(:@github_client, mock_github_client)
      end

      it 'calls contents with correct repository and path' do
        expect(mock_github_client).to receive(:contents)
          .with('department-of-veterans-affairs/va.gov-team-sensitive',
                path: 'products/accredited-representation-management/data/rep-org-addresses.xlsx')
          .and_return(mock_file_info)

        service.send(:fetch_github_file_info)
      end
    end

    describe '#fetch_file_content' do
      let(:url) { 'https://example.com/test.xlsx' }

      context 'when request is successful' do
        before do
          stub_request(:get, url).to_return(status: 200, body: 'file_content')
        end

        it 'returns the response body' do
          result = service.send(:fetch_file_content, url)
          expect(result).to eq('file_content')
        end
      end

      context 'when request fails' do
        before do
          stub_request(:get, url).to_return(status: 500, body: 'Server Error')
        end

        it 'returns nil' do
          result = service.send(:fetch_file_content, url)
          expect(result).to be_nil
        end
      end

      context 'when request redirects' do
        before do
          stub_request(:get, url).to_return(status: 302, body: '')
        end

        it 'returns nil for non-success responses' do
          result = service.send(:fetch_file_content, url)
          expect(result).to be_nil
        end
      end
    end
  end
end
