# frozen_string_literal: true

# rubocop:disable Rails/Output
# rubocop:disable Style/StringLiterals
# rubocop:disable Layout/LineLength
# rubocop:disable Lint/LiteralAsCondition
def initialize_bdn_clone
  Vye::BdnClone.destroy_all
  Vye::PendingDocument.destroy_all
  Vye::Verification.destroy_all
  Vye::UserProfile.destroy_all

  bdn_clone = Vye::BdnClone.create!(transact_date: Time.zone.today)
  puts "CURRENT TIME: #{Time.zone.now}"
  puts "----------------------------------------"
  puts ""
  puts "FROM BDN"
  bdn_clone
end

# rubocop :disable Rails/Exit
(puts 'Cannot run in production' && exit) unless %w[test development].include?(Rails.env)
# rubocop :enable Rails/Exit

idx = 0
parsed_awards = 0
beg_time = Time.zone.now

Timecop.freeze(Date.new(2025, 4, 1)) do
  File.foreach('tmp/WAVE.txt') do |row_str|
    record = Vye::BatchTransfer::IngressFiles::BdnLineExtraction.new(line: row_str.dup).attributes

    puts "----------------------------------------"
    puts "Processing Record Number: #{idx + 1}"
    puts "Raw Row: #{row_str}"
    puts "Parsed awards: #{record[:awards].size}"
    parsed_awards += record[:awards].size

    bdn_clone = idx.zero? ? initialize_bdn_clone : Vye::BdnClone.first
    idx += 1

    puts ""
    puts "STORED IN DATABASE"
    puts "----------------------------------------"

    ld = Vye::LoadData.new(source: :bdn_feed, locator: 0, bdn_clone:, records: record)
    (puts "FAILED TO LOAD DATA" and next) unless ld.valid?
    puts "Data loaded: #{Vye::Award.count} Award, #{Vye::UserInfo.count} UserInfo"
    user_info = Vye::UserInfo.last
    user_info.awards.all.find_each do |award|
      puts "  #{award.id}: #{award.award_begin_date} - #{award.award_end_date}"
    end

    verifications = Vye::UserInfo.last.pending_verifications
    puts ""
    puts "PENDING VERIFICATIONS (#{verifications.size})"
    puts "----------------------------------------"
    next if verifications.size.eql?(0)

    verifications.each do |verification|
      puts "  (Award: #{verification.award.id}) act_begin: #{verification.act_begin}, act_end: #{verification.act_end}, payment_date: #{verification.payment_date}"
      verification.source_ind = 'W'
      verification.save
    end

    puts ""
    puts "CERT THROUGH DATE"
    puts "----------------------------------------"
    current_date = Time.zone.today
    final_award_end = verifications.map { |pv| pv.act_end.to_date }.max

    cert_through_date =
      if current_date >= final_award_end
        # If we're on or past the final award, return that final date
        verifications.find { |pv| pv.act_end.to_date == final_award_end }&.act_end
      else
        # Otherwise, return either the max past date or end of previous month
        month_end = current_date.prev_month.end_of_month
        verifications
          .map { |pv| pv.act_end.to_date }
          .select { |date| date < current_date }
          .max || month_end
      end

    puts cert_through_date
  end
end

end_time = Time.zone.now

puts "\n\n"
puts "beg_time: #{beg_time}"
puts "end_time: #{end_time}"

elapsed_seconds = end_time - beg_time
hours = (elapsed_seconds / 3600).to_i
minutes = ((elapsed_seconds % 3600) / 60).to_i
seconds = (elapsed_seconds % 60).to_i
puts "Elapsed time: #{hours} hours, #{minutes} minutes, #{seconds} seconds"

puts "\n\n"
puts "-----------------------------"
puts "Records Processed    : #{idx}"
puts "Parsed Awards        : #{parsed_awards}"
puts "Awards Created       : #{Vye::Award.count}"
puts "Verifications Created: #{Vye::Verification.count}\n\n"
puts "case_eom             : #{Vye::Verification.where(trace: :case_eom).count}\n\n"
puts 'act_begin  act_end'
puts "abd        aed-1"
puts "case5  abd aed-1     : #{Vye::Verification.where(trace: :case5).count}"
puts "case6  abd aed-1     : #{Vye::Verification.where(trace: :case6).count}"
puts "case8  abd aed-1     : #{Vye::Verification.where(trace: :case8).count}"
puts "case9  abd aed-1     : #{Vye::Verification.where(trace: :case9).count}"
puts "case10 abd aed-1     : #{Vye::Verification.where(trace: :case10).count}\n\n"
puts "dlc        aed-1"
puts "case1  dlc aed-1     : #{Vye::Verification.where(trace: :case1).count}"
puts "case2  dlc aed-1     : #{Vye::Verification.where(trace: :case2).count}"
puts "case4  dlc aed-1     : #{Vye::Verification.where(trace: :case4).count}\n\n"
puts "dlc        ldpm"
puts "case3  dlc ldpm      : #{Vye::Verification.where(trace: :case3).count}\n\n"
puts "abd        ldpm"
puts "case7  abd ldpm      : #{Vye::Verification.where(trace: :case7).count}"
puts "------------------------------------------------"
# rubocop:enable Lint/LiteralAsCondition
# rubocop:enable Layout/LineLength
# rubocop:enable Style/StringLiterals
# rubocop:enable Rails/Output
