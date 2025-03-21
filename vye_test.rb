# row_str = "123158112345678999  20000921A3072500000000001933072020250228TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     43232    TLCLOSS307155289350022800202502182025022122025022800240006061D13CP202502242025022832025022800360006061D18CC202503032025030722025022800240006061D17CF202503102025050932025022800360006061D18CFA"
row_str = "123158112345678999  20000921A3072500000000001933072020250201TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     43232    TLCLOSS307155289350022800202502182025022122025020100240006061D13CP202502242025022832025020100360006061D18CC202503032025030722025020100240006061D17CF202503102025050932025020100360006061D18CFA"

record = Vye::BatchTransfer::IngressFiles::BdnLineExtraction.new(line: row_str.dup).attributes

Timecop.freeze(Date.new(2025,3,10)) do
  puts "CURRENT TIME: #{Time.now}"
  puts "----------------------------------------"
  puts ""
  puts "FROM BDN"
  puts "----------------------------------------"
  puts "Raw Row: #{row_str}"
  puts "Parsed SSN: #{record[:profile][:ssn]}"
  puts "Parsed awards: #{record[:awards].size}"
  record[:awards].each do |award|
    puts "  #{award[:award_begin_date]} - #{award[:award_end_date]}"
  end

  puts ""
  puts "STORED IN DATABASE"
  puts "----------------------------------------"
  Vye::BdnClone.destroy_all
  bdn_clone = Vye::BdnClone.create!(transact_date: Time.zone.today)
  ld = Vye::LoadData.new(source: :bdn_feed, locator: 0, bdn_clone:, records: record)
  (puts "FAILED TO LOAD DATA" and exit) unless ld.valid?
  puts "Data loaded: #{Vye::Award.count} Award, #{Vye::UserInfo.count} UserInfo"
  Vye::Award.all.each do |award|
    puts "  #{award.id}: #{award.award_begin_date} - #{award.award_end_date}"
  end

  verifications = Vye::UserInfo.first.pending_verifications
  puts ""
  puts "PENDING VERIFICATIONS (#{verifications.size})"
  puts "----------------------------------------"
  verifications.each do |verification|
    puts "  (Award: #{verification.award.id}) act_begin: #{verification.act_begin}, act_end: #{verification.act_end}, payment_date: #{verification.payment_date}"
  end

  exit if verifications.size == 0

  puts ""
  puts "CERT THROUGH DATE"
  puts "----------------------------------------"
  current_date = Time.zone.today
  final_award_end = verifications.map { |pv| pv.act_end.to_date }.max

  cert_through_date = if current_date >= final_award_end
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