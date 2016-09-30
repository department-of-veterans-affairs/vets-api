shared_context 'stub mvi find_candidate response' do
  before(:each) do
    allow(MVI::Service).to receive(:find_candidate).and_return(
      edipi: '1234^NI^200DOD^USDOD^A',
      icn: '1000123456V123456^NI^200M^USVHA^P',
      mhv: '123456^PI^200MHV^USVHA^A',
      status: 'active',
      given_names: %w(John William),
      family_name: 'Smith',
      gender: 'M',
      dob: '19800101',
      ssn: '555-44-3333'
    )
  end
end
