# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::BaseReloader do
  let(:reloader) { described_class.new }
  let(:individual_type_attorney) { AccreditedIndividual::INDIVIDUAL_TYPE_ATTORNEY }
  let(:individual_type_claim)    { AccreditedIndividual::INDIVIDUAL_TYPE_CLAIM_AGENT }
  let(:individual_type_representative) { AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE }

  describe '#find_or_initialize_by_id' do
    context 'locking' do
      it 'wraps the lookup in an advisory lock keyed by registration number when present' do
        payload = { 'Registration Num' => 'A123', 'POA Code' => '9G-B' }

        expect(AccreditedIndividual).to receive(:with_advisory_lock)
          .with('accredited_individual:A123:attorney')
          .and_yield

        reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
      end

      it 'does not lock when registration number is blank' do
        payload = { 'Registration Num' => '  ', 'POA Code' => '9G-B' }

        expect(AccreditedIndividual).not_to receive(:with_advisory_lock)

        reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
      end

      it 'yields within the advisory lock when a block is given' do
        payload = { 'Registration Num' => 'A123', 'POA Code' => '9G-B' }

        expect(AccreditedIndividual).to receive(:with_advisory_lock)
          .with('accredited_individual:A123:attorney')
          .and_yield

        yielded = false
        result = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney) do |rep|
          yielded = true
          rep
        end

        expect(yielded).to be(true)
        expect(result).to be_a(AccreditedIndividual)
      end

      it 'strips whitespace from registration number for locking and lookup' do
        payload = { 'Registration Num' => '  A123  ', 'POA Code' => '9G-B' }

        expect(AccreditedIndividual).to receive(:with_advisory_lock)
          .with('accredited_individual:A123:attorney')
          .and_yield

        rep = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
        expect(rep.registration_number).to eq('A123')
      end
    end

    context 'new record' do
      let(:payload) do
        {
          'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373a',
          'Registration Num' => 'A123',
          'First Name' => 'June',
          'Last Name' => 'Park   ',
          'Middle Initial' => 'Q',
          'POA Code' => ' 9G-B ',
          'Phone' => '(202) 555-0101',
          'City' => 'Seattle',
          'State' => ' WA ',
          'Zip' => '98109-1234'
        }
      end

      it 'initializes by registration_number and populates blanks, sanitizing inputs, without saving' do
        expect do
          rep = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
          expect(rep).to be_new_record

          expect(rep.registration_number).to eq('A123')
          expect(rep.first_name).to eq('June')
          expect(rep.last_name).to eq('Park')
          expect(rep.middle_initial).to eq('Q')
          expect(rep.phone).to eq('(202) 555-0101')
          expect(rep.city).to eq('Seattle')
          expect(rep.state_code).to eq('WA')
          expect(rep.zip_code).to eq('981091234')

          expect(rep.poa_code).to eq('9GB')
          expect(rep.individual_type).to eq('attorney')
        end.not_to change(AccreditedIndividual, :count)
      end

      it 'ignores blank POA Code and still adds individual_type' do
        payload_blank_poa = payload.merge('POA Code' => '  ')
        rep = reloader.send(:find_or_initialize_by_id, payload_blank_poa, individual_type_attorney)

        expect(rep.poa_code).to eq('')
        expect(rep.individual_type).to eq('attorney')
      end
    end

    context 'existing record' do
      let!(:existing) do
        AccreditedIndividual.create(
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373b',
          registration_number: 'B777',
          first_name: 'Alex',
          last_name: 'Ng',
          middle_initial: nil,
          phone: '555-0000',
          city: 'Denver',
          state_code: 'CO',
          zip_code: '80202',
          individual_type: 'attorney',
          poa_code: 'XYZ'
        )
      end

      it 'finds by registration_number + individual_type (no duplicate by name changes)' do
        payload = {
          'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373b',
          'Registration Num' => 'B777',
          'First Name' => 'Alexander',
          'Last Name' => 'Ng   ',
          'Middle Initial' => 'R',
          'Phone' => '999-9999',
          'City' => 'Boulder',
          'State' => ' WY ',
          'Zip' => '80301-9999',
          'POA Code' => ' X Y Z '
        }

        expect do
          rep = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
          expect(rep).to eq(existing)

          expect(rep.first_name).to eq('Alex')
          expect(rep.last_name).to eq('Ng')
          expect(rep.middle_initial).to eq('R')
          expect(rep.phone).to eq('555-0000')
          expect(rep.city).to eq('Denver')
          expect(rep.state_code).to eq('CO')
          expect(rep.zip_code).to eq('80202')

          expect(rep.poa_code).to eq('XYZ')
          expect(rep.individual_type).to eq('attorney')
        end.not_to change(AccreditedIndividual, :count)
      end

      it 'initializes a separate record for a different individual_type with the same registration number' do
        payload = {
          'Registration Num' => 'B777',
          'POA Code' => 'XY-Z ',
          'First Name' => 'Alex',
          'Last Name' => 'Ng',
          'AccrClaimAgentId' => '9c6f8595-4e84-42e5-b90a-270c422c373b'
        }

        expect do
          rep = reloader.send(:find_or_initialize_by_id, payload, individual_type_claim)

          expect(rep).to be_new_record
          expect(rep.registration_number).to eq('B777')
          expect(rep.individual_type).to eq('claims_agent')

          rep.save!
        end.to change(AccreditedIndividual, :count).by(1)

        expect(existing.reload.individual_type).to eq('attorney')
      end

      it 'finds the correct row when both attorney and claims_agent exist for the same registration number' do
        claim_agent = AccreditedIndividual.create!(
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c9999',
          registration_number: 'B777',
          first_name: 'Case',
          last_name: 'Agent',
          individual_type: 'claims_agent',
          poa_code: 'ABC',
          phone: '111-1111',
          city: 'Boulder',
          state_code: 'CO',
          zip_code: '80301'
        )

        attorney_payload = {
          'Registration Num' => 'B777',
          'AccrAttorneyId' => existing.ogc_id,
          'POA Code' => 'XYZ'
        }

        claim_payload = {
          'Registration Num' => 'B777',
          'AccrClaimAgentId' => claim_agent.ogc_id,
          'POA Code' => 'ABC'
        }

        attorney_rep = reloader.send(:find_or_initialize_by_id, attorney_payload, individual_type_attorney)
        claim_rep = reloader.send(:find_or_initialize_by_id, claim_payload, individual_type_claim)

        expect(attorney_rep).to eq(existing)
        expect(claim_rep).to eq(claim_agent)

        expect(attorney_rep.individual_type).to eq('attorney')
        expect(claim_rep.individual_type).to eq('claims_agent')
      end

      it 'does not overwrite an existing poa_code when sanitized payload poa_code is blank' do
        existing = AccreditedIndividual.create!(
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373b', # valid UUID
          registration_number: 'POA1',
          individual_type: 'attorney',
          poa_code: 'KEP' # 3 chars
        )

        payload = {
          'Registration Num' => 'POA1',
          'AccrAttorneyId' => existing.ogc_id,
          'POA Code' => '   ' # blank after sanitize
        }

        rep = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)

        expect(rep).to eq(existing)
        expect(rep.poa_code).to eq('KEP') # unchanged
      end
    end

    context 'edge cases' do
      it 'handles missing middle initial without error and does not set it for new record' do
        payload = {
          'Registration Num' => 'M001',
          'First Name' => 'Casey',
          'Last Name' => 'Lee',
          'Middle Initial' => nil,
          'POA Code' => 'ABC',
          'AccrRepresentativeId' => '9c6f8595-4e84-42e5-b90a-270c422c373a'
        }

        rep = reloader.send(:find_or_initialize_by_id, payload, individual_type_representative)
        expect(rep.middle_initial).to be_nil
        expect(rep.poa_code).to eq('ABC')
        expect(rep.individual_type).to eq('representative')
      end

      it 'strips non-word chars from state and zip only when setting from blank' do
        AccreditedIndividual.create!(
          registration_number: 'Z900',
          first_name: 'Pat',
          last_name: 'Brown',
          state_code: 'NY',
          poa_code: 'AAA',
          zip_code: '10001',
          individual_type: 'attorney',
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373a'
        )

        payload = {
          'Registration Num' => 'Z900',
          'State' => ' CA ',
          'Zip' => '94105-1234'
        }

        out = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
        expect(out.state_code).to eq('NY')
        expect(out.zip_code).to eq('10001')
      end

      it 'does not add poa_code when nil/blank after sanitization' do
        rep = reloader.send(
          :find_or_initialize_by_id,
          { 'Registration Num' => 'BLAH', 'POA Code' => ' - ' },
          individual_type_attorney
        )
        expect(rep.poa_code).to eq('')
        expect(rep.individual_type).to eq('attorney')
      end
    end

    context 'conditional population (only when blank)' do
      let!(:rep) do
        AccreditedIndividual.create!(
          registration_number: 'KEEP1',
          first_name: 'Kept',
          last_name: 'Name',
          phone: '555-1111',
          city: 'Kept City',
          state_code: 'KS',
          zip_code: '66002',
          individual_type: 'attorney',
          poa_code: 'AAA',
          ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373a'
        )
      end

      it 'does not overwrite existing phone/city/state/zip with non-blank payload' do
        payload = {
          'Registration Num' => 'KEEP1',
          'Phone' => '999-9999',
          'City' => 'New City',
          'State' => ' CA ',
          'Zip' => '94105-1234',
          'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373a'
        }
        out = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
        expect(out.phone).to eq('555-1111')
        expect(out.city).to eq('Kept City')
        expect(out.state_code).to eq('KS')
        expect(out.zip_code).to eq('66002')
      end

      it 'does not overwrite with blank payload values' do
        payload = {
          'Registration Num' => 'KEEP1',
          'Phone' => '',
          'City' => nil,
          'State' => '  ',
          'Zip' => nil,
          'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373a'
        }
        out = reloader.send(:find_or_initialize_by_id, payload, individual_type_attorney)
        expect(out.phone).to eq('555-1111')
        expect(out.city).to eq('Kept City')
        expect(out.state_code).to eq('KS')
        expect(out.zip_code).to eq('66002')
      end
    end
  end

  describe '#fetch_data' do
    let(:conn) { instance_double(Faraday::Connection) }
    let(:options) do
      instance_double(Faraday::RequestOptions, 'open_timeout=' => nil, 'timeout=' => nil)
    end

    before do
      allow(conn).to receive(:options).and_return(options)

      allow(Faraday).to receive(:new)
        .with(url: RepresentationManagement::BaseReloader::BASE_URL)
        .and_yield(conn)
        .and_return(conn)
    end

    it 'posts to the action and returns unique row hashes with headers mapped and blank headers removed' do
      html = <<~HTML
        <html><body>
          <table>
            <tr><th>Registration Num</th><th>First Name</th><th>Last Name</th><th>POA Code</th><th>  </th><th>AccrAttorneyId</th></tr>
            <tr><td>A1</td><td>June</td><td>Park</td><td>9G-B</td><td></td><td>9c6f8595-4e84-42e5-b90a-270c422c373a</td></tr>
            <tr><td>A1</td><td>June</td><td>Park</td><td>9G-B</td><td></td><td>9c6f8595-4e84-42e5-b90a-270c422c373a</td></tr>
            <tr><td>A2</td><td>Leo</td><td>Ng</td><td>FDN</td><td></td><td>9c6f8595-4e84-42e5-b90a-270c422c373b</td></tr>
          </table>
        </body></html>
      HTML

      expect(conn).to receive(:post).with('attorneyexcellist.asp', id: 'frmExcelList', name: 'frmExcelList')
                                    .and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'attorneyexcellist.asp')

      expect(rows.size).to eq 2
      expect(rows).to include(
        { 'Registration Num' => 'A1', 'First Name' => 'June', 'Last Name' => 'Park', 'POA Code' => '9G-B',
          'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373a' }
      )

      expect(rows).to include(
        { 'Registration Num' => 'A2', 'First Name' => 'Leo', 'Last Name' => 'Ng', 'POA Code' => 'FDN',
          'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373b' }
      )

      expect(rows.first).not_to have_key('')
    end

    it 'drops the header row and keeps only data rows' do
      html = <<~HTML
        <html><body>
          <table>
            <tr><td>Registration Num</td><td>First Name</td><td>Last Name</td><td>AccrAttorneyId</td></tr>
            <tr><td>B1</td><td>Ann</td><td>Lee</td><td>9c6f8595-4e84-42e5-b90a-270c422c373a</td></tr>
          </table>
        </body></html>
      HTML

      allow(conn).to receive(:post).and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'caexcellist.asp')
      expect(rows).to eq([{ 'Registration Num' => 'B1', 'First Name' => 'Ann', 'Last Name' => 'Lee',
                            'AccrAttorneyId' => '9c6f8595-4e84-42e5-b90a-270c422c373a' }])
    end

    it 'returns empty array when only headers exist' do
      html = <<~HTML
        <html><body>
          <table>
            <tr><td>Registration Num</td><td>First Name</td><td>Last Name</td></tr>
          </table>
        </body></html>
      HTML

      allow(conn).to receive(:post).and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'orgsexcellist.asp')
      expect(rows).to eq([])
    end

    it 'scrubs text and maps unusual characters without error' do
      html = <<~HTML
        <html><body>
          <table>
            <tr><th>Registration Num</th><th>First Name</th><th>Last Name</th><th>POA Code</th></tr>
            <tr><td>C1</td><td>J\u00FAn\u2028e</td><td>Pa\u00A0rk</td><td>9G-B</td></tr>
          </table>
        </body></html>
      HTML

      allow(conn).to receive(:post).and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'attorneyexcellist.asp')
      expect(rows.first['Registration Num']).to eq('C1')
      expect(rows.first['First Name']).to include('Jún')
      expect(rows.first['Last Name']).to include('rk')
      expect(rows.first['POA Code']).to eq('9G-B')
    end

    it 'returns empty array when no table is present in the HTML' do
      html = <<~HTML
        <html><body>
          <div>Error loading page</div>
        </body></html>
      HTML

      allow(conn).to receive(:post).and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'attorneyexcellist.asp')
      expect(rows).to eq([])
    end
  end
end
