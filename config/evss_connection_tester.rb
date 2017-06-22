puts "Bill ux here #{ARGV[0]}"

raise "Must provide a SSN!" unless ARGV[0]
ssn = ARGV[0]

Settings.mvi.mock = false

# build user
user = User.new(
  uuid: SecureRandom.uuid,
  first_name: 'Mark',
  middle_name: '',
  last_name: 'Webb',
  birth_date: '1950-10-04',
  gender: 'M',
  ssn: "#{ssn}",
  email: 'vets.gov.user+206@gmail.com',
  loa: {
    current: LOA::THREE,
    highest: LOA::THREE
  }
)
user.last_signed_in = Time.now.utc
user.va_profile.edipi = '1005329660'
headers = EVSS::AuthHeaders.new(user).to_h
service = EVSS::GiBillStatus::Service.new(headers)
service.get_gi_bill_status
