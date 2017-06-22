# frozen_string_literal: true
# Usage example:
# $> bundle exec rails r script/evss_connection_tester.rb 796066621 true
def to_boolean(str)
  str == 'true'
end

raise 'Must provide a SSN!' unless ARGV[0]
ssn = ARGV[0]

Settings.mvi.mock = to_boolean(ARGV[1]) if ARGV[1]

user = User.new(
  uuid: SecureRandom.uuid,
  first_name: 'Mark',
  middle_name: '',
  last_name: 'Webb',
  birth_date: '1950-10-04',
  gender: 'M',
  ssn: ssn.to_s,
  email: 'vets.gov.user+206@gmail.com',
  loa: {
    current: LOA::THREE,
    highest: LOA::THREE
  }
)
user.last_signed_in = Time.now.utc
begin
  user.va_profile
rescue Common::Exceptions::ValidationErrors
  puts 'User not found in MVI!'
end
puts 'User not found in  real MVI!' if user.va_profile.nil? && Settings.mvi.mock == false
user.va_profile.edipi = '1005329660'
headers = EVSS::AuthHeaders.new(user).to_h
service = EVSS::GiBillStatus::Service.new(headers)

puts "Connecting to... #{Settings.evss.url}"
response = service.get_gi_bill_status

returned_user = {
  first_name: response.first_name,
  last_name: response.last_name,
  date_of_birth: response.date_of_birth
}

puts "Response code: #{response.status}"
puts 'Non-200 response code! Check rails log for details' if response.status != 200
puts "Returned User : #{returned_user}"
