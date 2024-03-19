# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      module_function

      BDN_FEED_FILENAME = 'WAVE.txt'
      TIMS_FEED_FILENAME = 'tims32towave.txt'

      def bdn_feed_filename = BDN_FEED_FILENAME
      def tims_feed_filename = TIMS_FEED_FILENAME

      BDN_FEED_CONFIG =
        {
          main_line: {
            ssn: 9,
            file_number: 9,
            suffix: 2,
            dob: 8,
            mr_status: 1,
            rem_ent: 7,
            cert_issue_date: 8,
            del_date: 8,
            date_last_certified: 8,
            veteran_name: 20,
            address1: 20,
            address2: 20,
            address3: 20,
            address4: 20,
            address5: 20,
            zip_code: 9,
            stub_nm: 7,
            rpo_code: 3,
            fac_code: 8,
            payment_amt: 7
          },
          award_line: {
            award_begin_date: 8,
            award_end_date: 8,
            training_time: 1,
            payment_date: 8,
            monthly_rate: 7,
            begin_rsn: 2,
            end_rsn: 2,
            type_training: 1,
            number_hours: 2,
            type_hours: 1,
            cur_award_ind: 1
          }
        }.freeze

      def bdn_import(data)
        data.each_line do |line|
          parsed = BdnLineExtraction.new(line: line.chomp, result: {}, award_lines: [], awards: [])

          profile = Vye::UserProfile.build(parsed.attributes[:profile])
          info = profile.user_infos.build(parsed.attributes[:info])
          info.address_changes.build({ origin: 'backend' }.merge(parsed.attributes[:address]))

          profile.save!
        end
      end
    end
  end
end
