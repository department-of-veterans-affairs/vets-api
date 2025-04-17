# frozen_string_literal: true

# rubocop:disable Rails/Output
# rubocop:disable Style/StringLiterals
# rubocop:disable Layout/LineLength
Vye::BdnClone.destroy_all
bdn_clone = Vye::BdnClone.create!(transact_date: Time.zone.today)
puts "CURRENT TIME: #{Time.zone.now}"
puts "----------------------------------------"
puts ""
puts "FROM BDN"

awards_processed = 0
awards_rejected = 0
pending_verifications_created = 0

File.foreach('tmp/WAVE.txt') do |row_str|
  Timecop.freeze(Date.new(2025, 4, 1)) do
    puts "----------------------------------------"
    puts "Raw Row: #{row_str}"
    puts "Parsed SSN: #{record[:profile][:ssn]}"
    puts "Parsed awards: #{record[:awards].size}"

    record[:awards].each { |award| puts "  #{award[:award_begin_date]} - #{award[:award_end_date]}" }

    puts ""
    puts "STORED IN DATABASE"
    puts "----------------------------------------"
    ld = Vye::LoadData.new(source: :bdn_feed, locator: 0, bdn_clone:, records: record)
    (puts "FAILED TO LOAD DATA" and next) unless ld.valid?
    puts "Data loaded: #{Vye::Award.count} Award, #{Vye::UserInfo.count} UserInfo"
    Vye::UserInfo.last.awards.all.find_each do |award|
      puts "  #{award.id}: #{award.award_begin_date} - #{award.award_end_date}"
    end

    awards_processed += record[:awards].size
    verifications = Vye::UserInfo.last.pending_verifications
    pending_verifications_created += verifications.size
    records_rejected += record[:awards].size - verifications.size

    puts ""
    puts "PENDING VERIFICATIONS (#{verifications.size})"
    puts "----------------------------------------"
    verifications.each do |verification|
      puts "  (Award: #{verification.award.id}) act_begin: #{verification.act_begin}, act_end: #{verification.act_end}, payment_date: #{verification.payment_date}"
    end

    next if verifications.size.eql?(0)

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

puts "AWARDS PROCESSED             : #{awards_processed}"
puts "AWARDS REJECTED              : #{awards_rejected}"
puts "PENDING VERIFICATIONS CREATED: #{pending_verifications_created}"
puts "case_eom                     : #{Vye::Verification.where(trace: :case_eom).count}"
puts "case1                        : #{Vye::Verification.where(trace: :case1).count}"
puts "case2                        : #{Vye::Verification.where(trace: :case2).count}"
puts "case3                        : #{Vye::Verification.where(trace: :case3).count}"
puts "case4                        : #{Vye::Verification.where(trace: :case4).count}"
puts "case5                        : #{Vye::Verification.where(trace: :case5).count}"
puts "case6                        : #{Vye::Verification.where(trace: :case6).count}"
puts "case7                        : #{Vye::Verification.where(trace: :case7).count}"
puts "case8                        : #{Vye::Verification.where(trace: :case8).count}"
puts "case9                        : #{Vye::Verification.where(trace: :case9).count}"
puts "case10                       : #{Vye::Verification.where(trace: :case10).count}"
# rubocop:enable Layout/LineLength
# rubocop:enable Style/StringLiterals
# rubocop:enable Rails/Output
