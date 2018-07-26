FactoryBot.define do
  factory :gi_bill_feedback do
    state('pending')
    form(
      {
        onBehalfOf: 'Myself',
        educationDetails: {
          school: {
            name: 'school'
          },
          programs: {
            'MGIB-AD Ch 30': true
          }
        },
        issue: {
          'Student Loans': true
        },
        issueDescription: 'issueDescription',
        issueResolution: 'issueResolution'
      }.to_json
    )
  end
end
