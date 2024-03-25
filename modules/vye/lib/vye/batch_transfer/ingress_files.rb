# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      module_function

      BDN_FEED_FILENAME = 'WAVE.txt'
      TIMS_FEED_FILENAME = 'tims32towave.txt'

      def bdn_feed_filename = BDN_FEED_FILENAME
      def tims_feed_filename = TIMS_FEED_FILENAME

      def bdn_import(data)
        data.each_line do |line|
          parsed = BdnLineExtraction.new(line: line.chomp, result: {}, award_lines: [], awards: [])

          profile = Vye::UserProfile.build(parsed.attributes[:profile])
          info = profile.user_infos.build(parsed.attributes[:info])
          info.address_changes.build({ origin: 'backend' }.merge(parsed.attributes[:address]))
          parsed.attributes[:awards].each do |award|
            info.awards.build(award)
          end
          profile.save!
        end
      end
    end
  end
end
