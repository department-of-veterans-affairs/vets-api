# frozen_string_literal: true

module Vye
  module StagingData
    MAX_AWARD_COUNT = 2
    MAX_PENDING_DOCUMENT_COUNT = 2
    Vye::StagingData::Writer = Struct.new(:source, :target) do
      def output_root
        return @output_root if defined?(@output_root)

        timestamp = Time.zone.now.getlocal.strftime('%Y%m%dT%H%M%S%z')
        @output_root = target / format('staging-data-%<timestamp>s', timestamp:)
      end

      def rows
        return @rows if defined?(@rows)

        idme_files =
          [
            source / 'Administrative/vagov-users/test_users.csv'
          ]
        icn_files =
          [
            source / 'Administrative/vagov-users/mvi-staging-users.csv'
          ]

        raise 'Missing files in team sensitive working directory' unless (idme_files + icn_files).all?(&:exist?)

        @rows = Rows.new(idme_files:, icn_files:).get
      end

      def user_info(row)
        FactoryBot.attributes_for(:vye_user_info).except(:ssn, :icn, :file_number, :full_name).tap do |ui|
          ui[:ssn] = row[:ssn]
          ui[:file_number] = row[:ssn]
          ui[:icn] = row[:icn]
          ui[:full_name] = row[:full_name]
        end
      end

      def awards(_row)
        award_count = ((MAX_AWARD_COUNT * rand).floor + 1)
        (1..award_count).map do
          FactoryBot.attributes_for(:vye_award)
        end
      end

      def pending_documents(row)
        pending_document_count = (MAX_PENDING_DOCUMENT_COUNT * rand).floor
        (0..pending_document_count).map do
          FactoryBot.attributes_for(:vye_pending_document).tap do |pd|
            pd[:ssn] = row[:ssn]
          end
        end
      end

      def db_yaml(row)
        { user_info: user_info(row), awards: awards(row), pending_documents: pending_documents(row) }.to_json
      end

      def perform
        output_root.mkpath

        rows.each do |row|
          path = output_root / format('%s.yaml', row[:full_name].downcase.gsub(/\s+/, '-'))
          path.write(db_yaml(row))
        end
      end
    end
  end
end
