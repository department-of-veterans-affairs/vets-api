# frozen_string_literal: true
# Example usages:
#   Use Real MVI Lookup
#   $> bundle exec rails r script/evss_user_lookup.rb --ssn=796066621 --mock-mvi=false
#   Use Mock MVI Lookup
#   $> bundle exec rails r script/evss_user_lookup.rb --ssn=796066621 --mock-mvi=true
#   Skip MVI Lookup
#   $> bundle exec rails r script/evss_user_lookup.rb --ssn=796066621 --skip-mvi-lookup
argv_opts = OpenStruct.new
OptionParser.new do |opt|
  opt.banner = "Usage: bundle exec rails r script/evss_user_lookup [options]"
  opt.on('-s', '--ssn SSN', 'Social Security Number') { |o| argv_opts.ssn = o }
  opt.on('--skip-mvi-lookup', 'Skip MVI Lookup') { |o| argv_opts.skip_mvi = o }
  opt.on('--mock-mvi MOCK_MVI', 'Use the mock MVI') { |o| argv_opts.mock_mvi = o }
  # Rails runner consumes any -h or --help arguments, so I use --hh
  opt.on('--hh', "Prints Help for EVSS test script") do
    puts opt
    exit
  end
end.parse!

raise 'Must provide a SSN! (use --ssn=)' unless argv_opts.ssn
raise 'Must specify mock MVI (use --mock-mvi=true|false)' unless argv_opts.mock_mvi || argv_opts.skip_mvi

def to_boolean(str)
  str == 'true'
end

def fake_user(ssn)
  user = OpenStruct.new(
    loa: { current: 3 },
    first_name: 'Mark',
    last_name: 'Webb',
    last_signed_in: Time.now.utc,
    edipi: '1005329660',
    participant_id: '204225751',
    ssn: ssn
  )
end

def user_from_mvi(ssn)
  user = User.new(
    uuid: SecureRandom.uuid,
    first_name: 'Mark',
    middle_name: '',
    last_name: 'Webb',
    birth_date: '1950-10-04',
    gender: 'M',
    ssn: ssn,
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

  raise 'User not found in MVI!' if user.va_profile.nil?
  user.va_profile.edipi = '1005329660'
end

Settings.mvi.mock = to_boolean(argv_opts.mock_mvi) if argv_opts.mock_mvi

user = nil
if argv_opts.skip_mvi
  puts "Skipping MVI lookup..."
  user = fake_user(argv_opts.ssn.to_s)
else
  puts "Begining MVI lookup... mock=#{argv_opts.mock_mvi}"
  user = user_from_mvi(argv_opts.ssn.to_s)
end

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
