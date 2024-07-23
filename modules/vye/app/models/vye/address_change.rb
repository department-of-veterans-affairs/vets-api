# frozen_string_literal: true

module Vye
  class Vye::AddressChange < ApplicationRecord
    belongs_to :user_info

    has_kms_key

    has_encrypted(
      :veteran_name,
      :address1, :address2, :address3, :address4, :address5,
      :city, :state, :zip_code,
      key: :kms_key, **lockbox_options
    )

    validates(:origin, presence: true)

    validates(
      :veteran_name, :address1, :city,
      presence: true, if: -> { origin == 'frontend' }
    )

    # The 'cached' enum is a special case where the record was created on the frontend
    # and sent to the backend, but the backend has not yet processed it.
    # So it will not have been reflected from the backend until the next pull.
    enum(
      origin: { frontend: 'frontend', cached: 'cached', backend: 'backend' },
      _suffix: true
    )

    scope :backend, -> { where(origin: 'backend').limit(1) }

    scope :latest, -> { order(created_at: :desc).limit(1) }

    scope :export_ready, lambda {
      self
        .select('DISTINCT ON (vye_address_changes.user_info_id) vye_address_changes.*')
        .joins(user_info: :bdn_clone)
        .where(origin: 'frontend', vye_bdn_clones: { export_ready: true })
        .order('vye_address_changes.user_info_id, vye_address_changes.created_at DESC')
    }

    def self.report_rows
      export_ready.each_with_object([]) do |record, result|
        user_info = record.user_info

        result << {
          rpo: user_info.rpo_code,
          benefit_type: user_info.indicator,
          ssn: user_info.ssn,
          file_number: user_info.file_number,
          veteran_name: record.veteran_name,
          address1: record.address1,
          address2: record.address2,
          address3: record.address3,
          address4: record.address4,
          city: record.city,
          state: record.state,
          zip_code: record.zip_code
        }
      end
    end

    REPORT_TEMPLATE =
      YAML.load(<<-END_OF_TEMPLATE).gsub(/\n/, '')
      |-
        %3<rpo>s,
        %1<benefit_type>s,
        %9<ssn>s,
        %9<file_number>s,
        %20<veteran_name>s,
        %<address1>s,
        %<address2>s,
        %<address3>s,
        %<address4>s,
        %<city>s,
        %6<state>s,
        %5<zip_code>s
      END_OF_TEMPLATE

    private_constant :REPORT_TEMPLATE

    def self.write_report(io)
      report_rows.each do |record|
        io.puts(format(REPORT_TEMPLATE, record))
      end
    end

    def self.cache_new_address_changes
      # rubocop:disable Rails/FindEach
      export_ready
        .includes(user_info: { user_profile: :active_user_info })
        .each do |record|
          user_info = record.user_info.user_profile.active_user_info

          address_change = record.dup
          address_change.user_info = user_info
          address_change.origin = 'cached'
          address_change.save!
        end
      # rubocop:enable Rails/FindEach
    end
  end
end
