# frozen_string_literal: true

# This rake file is a diagnostic tool to investigate why a user might be getting
# an empty payment history response from the payment history controller.
# It checks various conditions that could cause payment history to be empty.

namespace :payment_history do
  desc 'Debug why payment history is empty for given ICNs'
  task :check_empty_history, [:icn] => :environment do |_t, args|
    icn = args[:icn]

    if icn.blank?
      puts 'Usage: rake payment_history:check_empty_history[ICN]'
      puts 'Example: rake payment_history:check_empty_history[1234567890V123456]'
      exit 1
    end

    puts 'Checking payment history status...'
    puts "ICN: #{mask_icn(icn)}"
    puts '-' * 40

    check_feature_flag
    mpi_profile = check_user_exists(icn)

    is_passing_policy = false
    is_passing_policy = check_policy_attributes(mpi_profile) if mpi_profile.present?

    person = nil
    person = check_bgs_file_number(mpi_profile) if is_passing_policy

    payment_history = nil
    payment_history = check_payment_history(mpi_profile, person) if person.present?

    check_payment_history_filters(payment_history) if payment_history.present?

    puts
  end

  def mask_value(value, visible_start: 4, visible_end: 0)
    return 'nil' if value.nil?
    return value if value.length <= visible_start

    masked_length = value.length - visible_start - visible_end
    return value if masked_length <= 0

    start_part = value[0...visible_start]
    end_part = visible_end.positive? ? value[-visible_end..] : ''

    "#{start_part}#{'*' * masked_length}#{end_part}"
  end

  def mask_icn(icn)
    mask_value(icn, visible_start: 4, visible_end: 0)
  end

  def mask_first_name(first_name)
    mask_value(first_name, visible_start: 1, visible_end: 0)
  end

  def mask_last_name(last_name)
    mask_value(last_name, visible_start: 1, visible_end: 0)
  end

  def mask_file_number(file_number)
    return 'nil' if file_number.nil?

    mask_value(file_number.to_s, visible_start: 0, visible_end: 4)
  end

  def mask_participant_id(participant_id)
    return 'nil' if participant_id.nil?

    mask_value(participant_id.to_s, visible_start: 3, visible_end: 2)
  end

  def check_feature_flag
    enabled = Flipper.enabled?(:payment_history)

    if enabled
      puts '✓ Feature Flag: payment_history is ENABLED'
    else
      puts '✗ Feature Flag: payment_history is DISABLED'
      puts '  This will cause payment history to return nil'
      puts '  Enable with: Flipper.enable(:payment_history)'
    end
  end

  def check_user_exists(icn)
    puts
    puts 'Checking if user can be found...'

    find_user_account(icn)
    find_mpi_profile(icn)
  end

  def find_user_account(icn)
    user_account = UserAccount.find_by(icn:)

    if user_account
      puts "✓ UserAccount found: ID #{user_account.id}"
      puts "  Created: #{user_account.created_at}"
      puts "  Verified: #{user_account.verified?}"
    else
      puts '✗ UserAccount not found in database'
      puts '  User may not have logged in or ICN may be incorrect'
    end
  end

  def find_mpi_profile(icn)
    mpi_service = MPI::Service.new
    response = mpi_service.find_profile_by_identifier(
      identifier: icn,
      identifier_type: MPI::Constants::ICN
    )
    handle_mpi_response(response)
  rescue Common::Exceptions::RecordNotFound, Faraday::Error => e
    puts "✗ Error querying MPI: #{e.message}"
    nil
  end

  def handle_mpi_response(response)
    if response.ok?
      puts '✓ User found in MPI'
      first_name = response.profile.given_names&.first
      last_name = response.profile.family_name
      puts "  Name: #{mask_first_name(first_name)} #{mask_last_name(last_name)}"
      puts "  ICN: #{mask_icn(response.profile.icn)}"
      response.profile
    elsif response.not_found?
      puts '✗ User not found in MPI'
      puts '  ICN may be invalid or user may not exist in Master Person Index'
      nil
    else
      puts "✗ MPI lookup failed: #{response.error&.message}"
      nil
    end
  end

  def check_policy_attributes(mpi_profile)
    puts
    puts 'Checking BGS policy access requirements...'

    has_icn = check_icn_presence(mpi_profile)
    has_ssn = check_ssn_presence(mpi_profile)
    has_participant_id = check_participant_id_presence(mpi_profile)

    all_present = has_icn && has_ssn && has_participant_id
    output_policy_summary(all_present)
    all_present
  end

  def check_icn_presence(mpi_profile)
    if mpi_profile.icn.present?
      puts "✓ ICN present: #{mask_icn(mpi_profile.icn)}"
      true
    else
      puts '✗ ICN missing'
      puts '  BGS policy requires ICN to be present'
      false
    end
  end

  def check_ssn_presence(mpi_profile)
    if mpi_profile.ssn.present?
      puts "✓ SSN present: ***-**-#{mpi_profile.ssn.to_s[-4..]}"
      true
    else
      puts '✗ SSN missing'
      puts '  BGS policy requires SSN to be present'
      false
    end
  end

  def check_participant_id_presence(mpi_profile)
    if mpi_profile.participant_id.present?
      puts "✓ Participant ID present: #{mask_participant_id(mpi_profile.participant_id)}"
      true
    else
      puts '✗ Participant ID missing'
      puts '  BGS policy requires Participant ID to be present'
      false
    end
  end

  def output_policy_summary(all_present)
    puts
    if all_present
      puts '✓ User has all required attributes for BGS policy access'
    else
      puts '✗ User is missing required attributes for BGS policy access'
      puts '  Payment history will be denied due to missing attributes'
    end
  end

  def check_bgs_file_number(mpi_profile)
    puts
    puts 'Checking BGS file number lookup...'

    user = create_user_struct(mpi_profile)
    lookup_bgs_person(user)
  rescue => e
    puts "✗ Error calling BGS person lookup: #{e.message}"
    puts "  #{e.class.name}"
    nil
  end

  def create_user_struct(mpi_profile)
    OpenStruct.new(
      icn: mpi_profile.icn,
      ssn: mpi_profile.ssn,
      participant_id: mpi_profile.participant_id
    )
  end

  def lookup_bgs_person(user)
    person = BGS::People::Request.new.find_person_by_participant_id(user:)
    handle_person_response(person)
  end

  def handle_person_response(person)
    case person.status
    when :ok
      handle_successful_lookup(person)
    when :error
      puts '✗ BGS person lookup failed with error status'
      puts '  This will cause payment history to be empty'
      nil
    when :no_id
      puts '✗ BGS person lookup failed - no ID found'
      puts '  This will cause payment history to be empty'
      nil
    else
      puts "✗ BGS person lookup failed with status: #{person.status}"
      nil
    end
  end

  def handle_successful_lookup(person)
    puts '✓ BGS person lookup succeeded'
    puts "  Status: #{person.status}"

    if person.file_number.blank?
      puts '✗ File number missing'
      puts '  Payment history requires a valid file number'
      return nil
    end

    puts "✓ File number present: #{mask_file_number(person.file_number)}"
    puts "  Participant ID: #{mask_participant_id(person.participant_id)}"
    puts "  SSN: ***-**-#{person.ssn_number.to_s[-4..]}"
    person
  end

  def check_payment_history(mpi_profile, person)
    puts
    puts 'Checking BGS payment history records...'

    user = create_payment_user_struct(mpi_profile)
    call_payment_service(user, person)
  rescue => e
    puts "✗ Error calling BGS payment history: #{e.message}"
    puts "  #{e.class.name}"
    nil
  end

  def create_payment_user_struct(mpi_profile)
    OpenStruct.new(
      icn: mpi_profile.icn,
      ssn: mpi_profile.ssn,
      participant_id: mpi_profile.participant_id,
      common_name: "#{mpi_profile.given_names&.first} #{mpi_profile.family_name}",
      # Email is hardcoded because:
      # 1. MPI profiles don't contain email addresses
      # 2. BGS::PaymentService uses common_name as primary external_key (email is only fallback)
      # 3. This email is never logged or exposed, only used internally for BGS authentication
      # 4. This is a diagnostic tool, not production code handling real user requests
      email: 'test@example.com'
    )
  end

  def call_payment_service(user, person)
    payment_service = BGS::PaymentService.new(user)
    response = payment_service.payment_history(person)
    handle_payment_response(response)
  end

  def handle_payment_response(response)
    if response.nil?
      puts '✗ BGS returned nil response'
      puts '  No payment records available'
      return nil
    end

    payments = response&.dig(:payments, :payment)
    output_payment_status(payments)
    payments
  end

  def output_payment_status(payments)
    if payments.nil?
      puts '✗ No payments found in response'
      puts '  BGS has no payment records for this veteran'
    elsif payments.empty?
      puts '✗ Payments array is empty'
      puts '  BGS has no payment records for this veteran'
    else
      payment_count = payments.is_a?(Array) ? payments.length : 1
      puts "✓ Payment records found: #{payment_count} payment(s)"
      puts '  BGS has payment history data available'
    end
  end

  def check_payment_history_filters(payment_history)
    puts
    puts 'Checking if payments are being filtered out...'

    payments = payment_history.is_a?(Array) ? payment_history : [payment_history]
    filtered_count = check_each_payment_filter(payments)
    output_filtering_summary(payments, filtered_count)
  end

  def check_each_payment_filter(payments)
    filtered_count = 0

    payments.each_with_index do |payment, index|
      filtered_count += 1 if check_payment_filtering(payment, index)
    end

    filtered_count
  end

  def check_payment_filtering(payment, index)
    puts
    puts "Payment #{index + 1}:"
    puts "  Payee type: #{payment[:payee_type]}"
    puts "  Beneficiary Participant ID: #{mask_participant_id(payment[:beneficiary_participant_id])}"
    puts "  Recipient Participant ID: #{mask_participant_id(payment[:recipient_participant_id])}"

    is_third_party_vendor = payment[:payee_type] == 'Third Party/Vendor'
    ids_dont_match = payment[:beneficiary_participant_id] != payment[:recipient_participant_id]

    if is_third_party_vendor
      puts "  ✗ FILTERED: Payee type is 'Third Party/Vendor'"
      true
    elsif ids_dont_match
      puts "  ✗ FILTERED: Beneficiary and Recipient IDs don't match"
      true
    else
      puts '  ✓ Would NOT be filtered'
      false
    end
  end

  def output_filtering_summary(payments, filtered_count)
    puts
    puts 'Summary:'
    puts "  Total payments: #{payments.length}"
    puts "  Filtered out: #{filtered_count}"
    puts "  Would be returned: #{payments.length - filtered_count}"

    puts
    if filtered_count == payments.length
      puts '✗ All payments are being filtered out!'
      puts '  This is why payment history appears empty'
    elsif filtered_count.positive?
      puts '⚠ Some payments are being filtered out'
    else
      puts '✓ No payments are being filtered'
    end
  end
end
