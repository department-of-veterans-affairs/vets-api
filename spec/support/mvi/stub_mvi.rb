# frozen_string_literal: true
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
        active_status: 'active'
      }
    )
  )
end
