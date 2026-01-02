# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::BaseReloader do
  let(:reloader) { Veteran::VSOReloader.new }
  let(:user_type_attorney) { Veteran::VSOReloader::USER_TYPE_ATTORNEY }
  let(:user_type_claim)    { Veteran::VSOReloader::USER_TYPE_CLAIM_AGENT }
  let(:user_type_vso)      { Veteran::VSOReloader::USER_TYPE_VSO }

  describe '#find_or_initialize_by_id' do
    context 'new record' do
      let(:payload) do
        {
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

      it 'initializes by representative_id and populates blanks, sanitizing inputs, without saving' do
        expect do
          rep = reloader.send(:find_or_initialize_by_id, payload, user_type_attorney)
          expect(rep).to be_new_record

          expect(rep.representative_id).to eq('A123')
          expect(rep.first_name).to eq('June')
          expect(rep.last_name).to eq('Park')
          expect(rep.middle_initial).to eq('Q')
          expect(rep.phone).to eq('(202) 555-0101')
          expect(rep.city).to eq('Seattle')
          expect(rep.state_code).to eq('WA')
          expect(rep.zip_code).to eq('981091234')

          expect(rep.poa_codes).to contain_exactly('9GB')
          expect(rep.user_types).to contain_exactly('attorney')
        end.not_to change(Veteran::Service::Representative, :count)
      end

      it 'ignores blank POA Code and still adds user_type' do
        payload_blank_poa = payload.merge('POA Code' => '  ')
        rep = reloader.send(:find_or_initialize_by_id, payload_blank_poa, user_type_attorney)

        expect(rep.poa_codes).to eq([])
        expect(rep.user_types).to contain_exactly('attorney')
      end
    end

    context 'existing record' do
      let!(:existing) do
        Veteran::Service::Representative.create!(
          representative_id: 'B777',
          first_name: 'Alex',
          last_name: 'Ng',
          middle_initial: nil,
          phone: '555-0000',
          city: 'Denver',
          state_code: 'CO',
          zip_code: '80202',
          user_types: ['attorney'],
          poa_codes: ['XYZ']
        )
      end

      it 'finds by representative_id only (no duplicate by name changes)' do
        payload = {
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
          rep = reloader.send(:find_or_initialize_by_id, payload, user_type_attorney)
          expect(rep).to eq(existing)

          expect(rep.first_name).to eq('Alex')
          expect(rep.last_name).to eq('Ng')
          expect(rep.middle_initial).to eq('R')
          expect(rep.phone).to eq('555-0000')
          expect(rep.city).to eq('Denver')
          expect(rep.state_code).to eq('CO')
          expect(rep.zip_code).to eq('80202')

          expect(rep.poa_codes.count { |p| p == 'XYZ' }).to eq 1
          expect(rep.user_types.count { |t| t == 'attorney' }).to eq 1
        end.not_to change(Veteran::Service::Representative, :count)
      end

      it 'adds new user_type once and appends new sanitized poa_code once' do
        payload = {
          'Registration Num' => 'B777',
          'POA Code' => ' 9G-B ',
          'First Name' => 'Alex',
          'Last Name' => 'Ng'
        }

        rep = reloader.send(:find_or_initialize_by_id, payload, user_type_claim)
        expect(rep.user_types).to contain_exactly('attorney', 'claim_agents')
        expect(rep.poa_codes).to match_array(%w[XYZ 9GB])
        expect(rep.user_types.count { |t| t == 'claim_agents' }).to eq 1
        expect(rep.poa_codes.count { |p| p == '9GB' }).to eq 1
      end
    end

    context 'edge cases' do
      it 'handles missing middle initial without error and does not set it for new record' do
        payload = {
          'Registration Num' => 'M001',
          'First Name' => 'Casey',
          'Last Name' => 'Lee',
          'Middle Initial' => nil,
          'POA Code' => 'ABC'
        }

        rep = reloader.send(:find_or_initialize_by_id, payload, user_type_vso)
        expect(rep.middle_initial).to be_nil
        expect(rep.poa_codes).to contain_exactly('ABC')
        expect(rep.user_types).to contain_exactly('veteran_service_officer')
      end

      it 'strips non-word chars from state and zip only when setting from blank' do
        Veteran::Service::Representative.create!(
          representative_id: 'Z900',
          first_name: 'Pat',
          last_name: 'Brown',
          state_code: 'NY',
          poa_codes: ['AAA'],
          zip_code: '10001'
        )

        payload = {
          'Registration Num' => 'Z900',
          'State' => ' CA ',
          'Zip' => '94105-1234'
        }

        out = reloader.send(:find_or_initialize_by_id, payload, user_type_attorney)
        expect(out.state_code).to eq('NY')
        expect(out.zip_code).to eq('10001')
      end

      it 'does not add poa_code when nil/blank after sanitization' do
        rep = reloader.send(:find_or_initialize_by_id, { 'Registration Num' => 'BLAH', 'POA Code' => ' - ' },
                            user_type_attorney)
        expect(rep.poa_codes).to eq([])
        expect(rep.user_types).to contain_exactly('attorney')
      end
    end

    context 'conditional population (only when blank)' do
      let!(:rep) do
        Veteran::Service::Representative.create!(
          representative_id: 'KEEP1',
          first_name: 'Kept',
          last_name: 'Name',
          phone: '555-1111',
          city: 'Kept City',
          state_code: 'KS',
          zip_code: '66002',
          user_types: ['attorney'],
          poa_codes: ['AAA']
        )
      end

      it 'does not overwrite existing phone/city/state/zip with non-blank payload' do
        payload = {
          'Registration Num' => 'KEEP1',
          'Phone' => '999-9999',
          'City' => 'New City',
          'State' => ' CA ',
          'Zip' => '94105-1234'
        }
        out = reloader.send(:find_or_initialize_by_id, payload, user_type_attorney)
        expect(out.phone).to eq('555-1111')
        expect(out.city).to eq('Kept City')
        expect(out.state_code).to eq('KS')
        expect(out.zip_code).to   eq('66002')
      end

      it 'does not overwrite with blank payload values' do
        payload = {
          'Registration Num' => 'KEEP1',
          'Phone' => '',
          'City' => nil,
          'State' => '  ',
          'Zip' => nil
        }
        out = reloader.send(:find_or_initialize_by_id, payload, user_type_attorney)
        expect(out.phone).to eq('555-1111')
        expect(out.city).to eq('Kept City')
        expect(out.state_code).to eq('KS')
        expect(out.zip_code).to   eq('66002')
      end
    end

    context 'user_types accumulate without duplication' do
      it 'accumulates types across calls and never duplicates' do
        payload = { 'Registration Num' => 'UT1', 'First Name' => 'X', 'Last Name' => 'Y', 'POA Code' => 'BBB' }

        out1 = reloader.send(:find_or_initialize_by_id, payload, user_type_attorney)
        out1.save
        expect(out1.user_types).to contain_exactly('attorney')

        out2 = reloader.send(:find_or_initialize_by_id, payload, user_type_claim)
        out2.save
        expect(out2.user_types.sort).to eq(%w[attorney claim_agents])

        out3 = reloader.send(:find_or_initialize_by_id, payload, user_type_claim)
        out3.save
        expect(out3.user_types.count { |t| t == 'claim_agents' }).to eq 1
      end
    end
  end

  describe '#fetch_data' do
    let(:conn) { instance_double(Faraday::Connection) }

    before do
      allow(Faraday).to receive(:new).with(url: Veteran::BaseReloader::BASE_URL).and_return(conn)
    end

    it 'posts to the action and returns unique row hashes with headers mapped and blank headers removed' do
      html = <<~HTML
        <html><body>
          <table>
            <tr><th>Registration Num</th><th>First Name</th><th>Last Name</th><th>POA Code</th><th>  </th></tr>
            <tr><td>A1</td><td>June</td><td>Park</td><td>9G-B</td><td></td></tr>
            <tr><td>A1</td><td>June</td><td>Park</td><td>9G-B</td><td></td></tr>
            <tr><td>A2</td><td>Leo</td><td>Ng</td><td>FDN</td><td></td></tr>
          </table>
        </body></html>
      HTML

      expect(conn).to receive(:post).with('attorneyexcellist.asp', id: 'frmExcelList', name: 'frmExcelList')
                                    .and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'attorneyexcellist.asp')

      expect(rows.size).to eq 2
      expect(rows).to include(
        { 'Registration Num' => 'A1', 'First Name' => 'June', 'Last Name' => 'Park', 'POA Code' => '9G-B' }
      )

      expect(rows).to include(
        { 'Registration Num' => 'A2', 'First Name' => 'Leo', 'Last Name' => 'Ng', 'POA Code' => 'FDN' }
      )

      expect(rows.first).not_to have_key('')
    end

    it 'drops the header row and keeps only data rows' do
      html = <<~HTML
        <html><body>
          <table>
            <tr><td>Registration Num</td><td>First Name</td><td>Last Name</td></tr>
            <tr><td>B1</td><td>Ann</td><td>Lee</td></tr>
          </table>
        </body></html>
      HTML

      allow(conn).to receive(:post).and_return(double(body: html))

      rows = reloader.send(:fetch_data, 'caexcellist.asp')
      expect(rows).to eq([{ 'Registration Num' => 'B1', 'First Name' => 'Ann', 'Last Name' => 'Lee' }])
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
  end
end
