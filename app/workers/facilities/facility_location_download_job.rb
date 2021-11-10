# frozen_string_literal: true

module Facilities
  class FacilityLocationDownloadJob
    include Sidekiq::Worker

    def perform(type)
      @type = type
      ActiveRecord::Base.transaction do
        process_changes
        process_deletes
      end
    end

    private

    def process_changes
      (fresh_by_fingerprint.keys - existing_by_fingerprint.keys).each do |fingerprint|
        fresh_record = fresh_by_fingerprint[fingerprint]
        if existing_by_unique_id[fresh_record.unique_id]
          klass.update(fresh_record.unique_id, updatable_attrs(fresh_record))
        else
          fresh_record.save
        end
      end
    end

    def process_deletes
      return if fresh_by_unique_id.empty? # do not wipe cached data if endpoint returns empty

      missing_ids = (existing_by_unique_id.keys - fresh_by_unique_id.keys)
      klass.delete(missing_ids) if missing_ids.any?
    end

    def existing_by_fingerprint
      @existing_by_fingerprint ||= fetch_existing_data.index_by(&:first)
    end

    def existing_by_unique_id
      @existing_by_unique_id ||= fetch_existing_data.index_by(&:last)
    end

    def fetch_existing_data
      @fetch_existing_data ||= klass
                               .where("classification != 'State Cemetery' OR classification is NULL")
                               .pluck(:fingerprint, :unique_id)
    end

    def fresh_by_fingerprint
      @fresh_by_fingerprint ||= fetch_fresh_data.index_by(&:fingerprint)
    end

    def fresh_by_unique_id
      @fresh_by_unique_id ||= fetch_fresh_data.index_by(&:unique_id)
    end

    def fetch_fresh_data
      @fetch_fresh_data ||= klass.pull_source_data.uniq(&:id)
    end

    def klass
      Facilities::Mappings::CLASS_MAP[@type]
    end

    def updatable_attrs(record)
      record.attributes.except('created_at', 'updated_at', 'unique_id')
    end
  end
end
