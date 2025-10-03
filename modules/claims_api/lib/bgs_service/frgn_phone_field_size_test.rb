# frozen_string_literal: true

# ============================================================================
# BGS FRGN_PHONE_RFRNC_TXT Field Size Test
# ============================================================================
#
# CONTEXT:
#   API-48712: International phone number support

# FINDINGS:
#   ✅ Field exists: VNP_PTCPNT_PHONE.FRGN_PHONE_RFRNC_TXT
#   ✅ Maximum size: 30 characters (confirmed via ORA-12899 error)
#   ✅ Can store most international numbers (schema allows up to 23 chars)
#
# USAGE:
#   1. Get valid BGS IDs from a successful POA request
#   2. Update the IDs in the test below
#   3. Run in Rails console: load 'modules/claims_api/lib/bgs_service/frgn_phone_field_size_test.rb'
#
# RESULT:
#   - 10 chars: ✅ SUCCESS
#   - 15 chars: ✅ SUCCESS
#   - 20 chars: ✅ SUCCESS
#   - 23 chars: ✅ SUCCESS (our schema max)
#   - 30 chars: ✅ SUCCESS (BGS max)
#   - 35 chars: ❌ ORA-12899 error - "actual: 35, maximum: 30"
#
# ============================================================================

require 'bgs_service/vnp_ptcpnt_phone_service'

puts '=' * 80
puts 'BGS FRGN_PHONE_RFRNC_TXT Field Size Test'
puts '=' * 80

# ============================================================================
# STEP 1: UPDATE THESE IDS WITH VALID VALUES FROM A POA REQUEST
# ============================================================================
#
# How to get valid IDs:
# 1. Submit a POA request
# 2. Check Rails logs for the debug output

# REPLACE WITH YOUR ACTUAL VALUES:
veteran_participant_id = '600049324' # REPLACE ME
vnp_proc_id = '3866495'              # REPLACE ME
vnp_ptcpnt_id = '199470'             # REPLACE ME

puts "\nUsing BGS IDs:"
puts "  veteran_participant_id: #{veteran_participant_id}"
puts "  vnp_proc_id: #{vnp_proc_id}"
puts "  vnp_ptcpnt_id: #{vnp_ptcpnt_id}"
puts ''
puts '  If these are invalid, you will get ORA-02291 foreign key errors'
puts '=' * 80

# ============================================================================
# STEP 2: RUN THE TEST
# ============================================================================

phone_service = ClaimsApi::VnpPtcpntPhoneService.new(
  external_uid: veteran_participant_id,
  external_key: veteran_participant_id
)

# Test progressively longer strings to find exact limit
test_lengths = [10, 15, 20, 23, 25, 30, 35, 40, 50]

puts "\n Testing Field Size Limit"
puts '=' * 80

max_successful_length = 0

test_lengths.each do |length|
  test_value = "+#{('1' * (length - 1))}"

  phone_opts = {
    vnp_proc_id: vnp_proc_id,
    vnp_ptcpnt_id: vnp_ptcpnt_id,
    phone_type_nm: 'Daytime',
    phone_nbr: '5551234567',
    frgn_phone_rfrnc_txt: test_value,
    efctv_dt: Time.current.iso8601
  }

  display_value = test_value.length > 30 ? "#{test_value[0..30]}..." : test_value
  puts "\n📱 Testing #{length} chars: '#{display_value}'"

  begin
    response = phone_service.vnp_ptcpnt_phone_create(phone_opts)

    puts " SUCCESS at #{length} characters!"
    max_successful_length = length

    if response[:vnp_ptcpnt_phone_id]
      puts " Created phone ID: #{response[:vnp_ptcpnt_phone_id]}"
    end

    if response[:frgn_phone_rfrnc_txt]
      stored_value = response[:frgn_phone_rfrnc_txt]
      display_stored = stored_value.length > 40 ? "#{stored_value[0..40]}..." : stored_value
      puts " Stored: #{display_stored}"
    end
  rescue StandardError => e
    error_msg = e.message

    if error_msg =~ /ORA-12899/i
      puts "   ❌ TOO LARGE - Field size limit exceeded at #{length} chars"

      if error_msg =~ /actual:\s*(\d+),\s*maximum:\s*(\d+)/i
        actual = ::Regexp.last_match(1).to_i
        maximum = ::Regexp.last_match(2).to_i
        puts "   BGS Database Limit: #{maximum} characters"
        puts "   Attempted: #{actual} characters"

        puts "\n" + '=' * 80
        puts 'RESULT: FRGN_PHONE_RFRNC_TXT field limit = ' \
             "#{maximum} characters"
        puts '=' * 80

        if maximum >= 23
          puts '✅ Field CAN store our max international numbers (23 chars)'
          puts '   → Can use this field for international phone storage'
        else
          puts '❌ Field is TOO SMALL for our max international numbers (need 23 chars)'
          puts '   → Cannot use this field alone for international phone storage'
        end

        break # Exit loop - we found the limit
      else
        puts "   Error: #{error_msg[0..200]}"
        break
      end

    elsif error_msg =~ /ORA-02291/i
      puts '   ❌ Foreign key constraint - Invalid BGS IDs'
      puts '   Please update the IDs at the top of this script with valid values'
      puts "   Error: #{error_msg[0..150]}"
      break

    elsif error_msg =~ /Outage detected/i
      puts '   ⚠️  Circuit breaker active - waiting 3 seconds...'
      sleep 3

    else
      puts "   ⚠️  Other error: #{error_msg[0..150]}"
    end
  end
end

# ============================================================================
# STEP 3: SUMMARY
# ============================================================================

puts "\n" + '=' * 80
puts 'TEST SUMMARY'
puts '=' * 80

if max_successful_length.positive?
  puts "\n✅ Maximum successful storage: #{max_successful_length} characters"
  puts ''
  puts 'CONCLUSION:'
  puts "  - BGS FRGN_PHONE_RFRNC_TXT field supports up to #{max_successful_length} characters"
  puts '  - Our schema allows international numbers up to 23 characters'

  if max_successful_length >= 23
    puts '  - ✅ This field CAN be used for international phone number storage'
    puts ''
    puts 'IMPLEMENTATION RECOMMENDATION:'
    puts '  1. Use frgnPhoneRfrncTxt for international numbers (≤30 chars)'
    puts '  2. Add validation to reject/handle numbers >30 chars'
    puts '  3. Store country_code in cntryNbr, area_code in areaNbr'
    puts '  4. Keep phone_nbr for domestic US numbers or as fallback'
  else
    puts '  - ❌ This field CANNOT be used for all international numbers'
    puts '  - Alternative solution needed for numbers >#{max_successful_length} chars'
  end
else
  puts "\n⚠️  Test did not complete successfully"
  puts 'Please check the error messages above and:'
  puts '  1. Verify BGS IDs are valid'
  puts '  2. Ensure BGS service is accessible'
  puts '  3. Check Rails logs for detailed error information'
end

puts "\n" + '=' * 80
puts 'RELATED FILES:'
puts '=' * 80
puts '  - Service: modules/claims_api/lib/bgs_service/vnp_ptcpnt_phone_service.rb'
puts '  - BGS Catalog: bgs-catalog/VnpPtcpntPhoneWebServiceBean/.../request.xml'
puts '  - Database: VNP_PTCPNT_PHONE table, FRGN_PHONE_RFRNC_TXT column'
puts '  - Ticket: API-48712 (International phone number support)'
puts '=' * 80
