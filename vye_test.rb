# row_str = "123158112345678999  20000921A3072500000000001933072020250228TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     43232    TLCLOSS307155289350022800202502182025022122025022800240006061D13CP202502242025022832025022800360006061D18CC202503032025030722025022800240006061D17CF202503102025050932025022800360006061D18CFA"
# row_str = "123158112345678999  20000921A3072500000000001933072020250201TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     43232    TLCLOSS307155289350022800202502182025022122025020100240006061D13CP202502242025022832025020100360006061D18CC202503032025030722025020100240006061D17CF202503102025050932025020100360006061D18CFA"
# row_str = "123158112345678999  20001103A2868333202503211934062720250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     98373    K KUZME3511192044703819532025010600000000220250301012190060  B05QP2025012200000000420250301024380070  B16QC202503132025032542025030102438007261B11QF                                         B"
# row_str = "123158112345678999  19980903A1230000202503211932121420250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     79936    L CRUZ 351219701100243800202501062025020342025030102438006061B04SP202502032025030342025030102438006061B04SC202503032025033142025030102438006061B04SF                                         B"
# row_str = "123158112345678999  19960414A1404167000000001932021620250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     30224    BNPITTM351219701100088183202501062025020342025030100481006061B04SP202502032025030342025030100481006061B04SC202503032025033142025030100481006061B04SF202504072025063042025030100481006061B03SFA"

# This generates the erroneous result w/a run date of 3/31. A run date of 4/1 does not create a pv unless the award indicator is 'C' in which case it
# produces the result Shay says it should (3/30). So 2 problems: 1) The run date is ?, and 2) the award indicator is not 'C'
row_str = "123158112345678999  19951009A1943333202503212028050420250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     64747    RLJOHNS351249445030243800202412092025020342025030102438006061B06SP2025020300000000420250301024380029  B09SC202503032025033142025030102438007261B07SF                                         B"
# Same row as above but the award indicator is 'C' and the run date is 4/1.
# row_str = "123158112345678999  19951009A1943333202503212028050420250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     64747    RLJOHNS351249445030243800202412092025020342025030102438006061B06SP2025020300000000420250301024380029  B09SC202503032025033142025030102438007261B07SC                                         B"

# row_str = "123158112345678999  19850509A2643333000000001934090120250331TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     74021    SDPALME351219701100081267202411252024120342025033102438007264B04SP202501062025033142025033102438006061B04SC202504072025060242025033102438006061B04SF202506022025072842025033102438006061B07SFB"

# 4/4/25 reject w/a run date of 4/2(?) wave file pulled on 4/3/25
# row_str = "123158112345678999  19881104A0873333202503211935060120250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     34746    ADGOFFN351218110100170660202501132025020742025030102438006061B04QP202502102025030742025030102438006061B06QC                                                                                  B"

# Wave pulled from s3 on 4/4
# row_str = "123158112345678999  19881104A0793333000000001935060120250401TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                                     34746    ADGOFFN351218110100219420202502102025030742025040102438006061B06QP202503102025040442025040102438006061B04QC                                                                                  B"

# Phone reject from 4/3 (using wave from 4/1
# row_str = "123158112345678999  20041113A2823333202503211938033020250301TESTERS J DOESSON   9999 EASTBUMFK DR S COLUMBUS OH                                                      73075    EPBARLO351149274360083100202410012024121542025030100831003761B15SP2025012100000000420250301008310060  B16SC202503162025051842025030100831007261B12SF                                                        A"

record = Vye::BatchTransfer::IngressFiles::BdnLineExtraction.new(line: row_str.dup).attributes

Timecop.freeze(Date.new(2025, 4, 1)) do
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