# frozen_string_literal: true

module Vye
  module StagingData
    class Build
      MAX_AWARD_COUNT = 4
      MAX_PENDING_DOCUMENT_COUNT = 1
      PATHS =
        {
          test_users: 'Administrative/vagov-users/test_users.csv',
          mvi_staging_users: 'Administrative/vagov-users/mvi-staging-users.csv'
        }.freeze

      private_constant :PATHS, :MAX_AWARD_COUNT, :MAX_PENDING_DOCUMENT_COUNT

      def dump
        return @dump if defined?(@dump)

        rows.each do |row|
          summary = row[:summary]
          path = root / format('%s.yaml', summary[:full_name].downcase.gsub(/\s+/, '-'))
          path.write(row.to_yaml)
        end

        @dump = true
      end

      private

      attr_reader :test_users, :mvi_staging_users, :target

      def initialize(target:)
        yield(PATHS) => { test_users:, mvi_staging_users: }
        @test_users = CSV.new(test_users, headers: true).each.to_a
        @mvi_staging_users = CSV.new(mvi_staging_users, headers: true).each.to_a
        @target = target
      end

      def cross
        return @cross if defined?(@cross)

        product =
          test_users
          .product(mvi_staging_users)
          .select do |tu, msu|
            tu['ssn'] == msu['ssn']
          end

        @cross = product.group_by { |x| x.first['ssn'] }.values.pluck(0)
      end

      def rows
        @rows ||=
          cross
          .map do |tu, msu|
            tu = extract_from_tu(tu)
            msu = extract_from_msu(msu)

            summary = {}.merge(tu).merge(msu)

            {
              summary:,
              profile: fake_user_profile(summary:),
              info: fake_user_info(summary:),
              address: fake_address_change(summary:),
              awards: fake_awards,
              pending_documents: fake_pending_documents
            }
          end
      end

      def root
        return @root if defined?(@root)

        timestamp = Time.zone.now.strftime('%Y%m%dT%H%M%S%z')
        root = target / format('vye/staging-data-%<timestamp>s', timestamp:)
        root.mkpath

        @root = root
      end

      def fake_user_profile(summary:)
        FactoryBot.attributes_for(:vye_user_profile).except(:ssn, :icn, :file_number).tap do |record|
          record[:ssn] = summary[:ssn]
          record[:file_number] = summary[:ssn]
          record[:icn] = summary[:icn]
        end
      end

      def fake_user_info(summary:)
        FactoryBot.attributes_for(:vye_user_info).except(:full_name).tap do |record|
          name = summary[:full_name]
          parts = name.split(/\s+/)
          initials = parts.pluck(0).join
          rest = parts[-1][1..(7 - initials.length)]
          stub_nm = [initials, rest].join.upcase

          record[:stub_nm] = stub_nm
          record[:file_number] = summary[:ssn]
        end
      end

      def fake_address_change(summary:)
        FactoryBot.attributes_for(:vye_address_backend).tap do |record|
          record[:veteran_name] = summary[:full_name]
        end
      end

      def fake_awards
        (1..rand(1..4)).map do
          FactoryBot.attributes_for(:vye_award)
        end
      end

      def fake_pending_documents
        (0..rand(0..1)).map do
          FactoryBot.attributes_for(:vye_pending_document)
        end
      end

      def extract_from_tu(row)
        ssn = scrub_ssn(row['ssn'])
        idme_uuid = row['idme_uuid']&.strip
        email = row['email']&.strip
        password = row['password']&.strip
        full_name =
          row.values_at(
            'first_name',
            'middle_name',
            'last_name'
          ).compact.map(&:strip).map(&:capitalize).join(' ').strip

        { ssn:, idme_uuid:, email:, password:, full_name: }
      end

      def extract_from_msu(row)
        ssn = scrub_ssn(row['ssn'])
        icn = row['icn']&.strip
        full_name =
          row.values_at(
            'first_name',
            'middle_name',
            'last_name'
          ).compact.map(&:strip).map(&:capitalize).join(' ').strip

        { ssn:, icn:, full_name: }
      end

      def scrub_ssn(value)
        value&.gsub(/\D/, '')&.strip
      end
    end
  end
end
