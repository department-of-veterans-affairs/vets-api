FactoryBot.define do
  factory :gi_bill_feedback do
    state('pending')
    form(
      {
        address: {
          street: 'street',
          street2: 'street2',
          city: 'city',
          state: 'VA',
          postalCode: '12345',
          country: 'US'
        },
        serviceBranch: 'NOAA/PHS',
        serviceAffiliation: 'Veteran',
        fullName: {
          prefix: 'Mr.',
          first: 'Test',
          middle: 'middle',
          last: 'last',
          suffix: 'Jr.'
        },
        serviceDateRange: {
          from: "2000-01-01",
          to: "2000-01-02"
        },
        anonymousEmail: 'foo@foo.com',
        onBehalfOf: 'Myself',
        educationDetails: {
          school: {
            name: 'school'
          },
          facilityCode: '123',
          programs: {
            'MGIB-AD Ch 30': true
          },
          assistance: {
            TA: true
          }
        },
        issue: {
          studentLoans: true
        },
        issueDescription: 'issueDescription',
        issueResolution: 'issueResolution'
      }.to_json
    )
  end
end
