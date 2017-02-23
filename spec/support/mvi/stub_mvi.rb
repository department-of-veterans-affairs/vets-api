# frozen_string_literal: true
# rubocop:disable Metrics/MethodLength
def stub_mvi
  allow(Mvi).to receive(:find).and_return(
    Mvi.new(
      uuid: 'abc123',
      response: {
        status: 'OK',
        birth_date: '18090212',
        edipi: '1234^NI^200DOD^USDOD^A',
        vba_corp_id: '12345678^PI^200CORP^USVBA^A',
        family_name: 'Lincoln',
        gender: 'M',
        given_names: %w(Abraham),
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv_ids: ['123456^PI^200MH^USVHA^A'],
        ssn: '272111863',
        active_status: 'active',
        address: {
          street_address_line: '140 Rock Creek Church Road NW',
          city: 'Washington',
          state: 'DC',
          postal_code: '20011',
          country: 'USA'
        },
        home_phone: '2028290436',
        suffix: nil
      }
    )
  )
end

def stub_mvi_not_found
  allow(Mvi).to receive(:find).and_return(
    Mvi.new(
      uuid: 'abc123',
      response: {
        status: 'NOT_FOUND'
      }
    )
  )
end
