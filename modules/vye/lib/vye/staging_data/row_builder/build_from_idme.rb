# frozen_string_literal: true

module Vye
  module StagingData
    module RowBuilder
      Vye::StagingData::RowBuilder::BuildFromIdme = Struct.new(:index, :csv) do
        include Common

        def call
          values => {ssn:, idme_uuid:, email:, password:, full_name:}

          got_matching_row =
            proc { |row|
              row[:idme_uuid] == idme_uuid && row[:email] == email && row[:password] == password
            }

          index.tap do |_|
            next if ssn.blank?
            next if index[ssn].any?(&got_matching_row)

            check_password_mismatch!
            check_email_mismatch!
            index[ssn].push(ssn:, idme_uuid:, email:, password:, full_name:)
          end
        end

        private

        def check_password_mismatch!
          values => {ssn:, idme_uuid:, email:, password:, full_name:}

          predicate = proc do |row|
            row[:idme_uuid] == idme_uuid && row[:email] == email && row[:password] != password
          end

          return unless index[ssn].any?(&predicate)

          passwords = index[ssn].pluck(:password)
          raise format(
            'password missmatch for %<ssn>s: %<password>s vs %<passwords>p)',
            { ssn:, password:, passwords: }
          )
        end

        def check_email_mismatch!
          values => {ssn:, idme_uuid:, email:, password:, full_name:}

          predicate = proc do |row|
            row[:idme_uuid] == idme_uuid && row[:email] != email
          end

          return unless index[ssn].any?(&predicate)

          emails = index[ssn].pluck(:email)
          raise format(
            'email missmatch for %<ssn>s: %<email>s vs %<emails>p)',
            { ssn:, email:, emails: }
          )
        end

        def get_values
          ssn = extract_ssn
          idme_uuid = csv['idme_uuid']&.strip
          email = csv['email']&.strip
          password = csv['password']&.strip
          full_name =
            csv.values_at(
              'first_name',
              'middle_name',
              'last_name'
            ).compact.map(&:strip).map(&:capitalize).join(' ').strip

          { ssn:, idme_uuid:, email:, password:, full_name: }
        end

        def values
          @values ||= get_values
        end
      end
    end
  end
end
