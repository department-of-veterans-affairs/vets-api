# frozen_string_literal: true

module Webhooks
  class Subscription < ApplicationRecord
    self.table_name = 'webhooks_subscriptions'
    def self.get_notification_urls(api_name:, consumer_id:, event:, api_guid: nil)
      sql = "
        select json_agg(agg.urls)::jsonb as event_urls
        from (
        select distinct (event_json.sub_event_array -> 'urls') as urls
        from (
          select jsonb_array_elements(subs.api_consumer_subscriptions) as sub_event_array
          from (
            select a.events -> 'subscriptions' as api_consumer_subscriptions
            from webhooks_subscriptions a
            where a.api_name = $1
            and a.consumer_id = $2
            and a.events -> 'subscriptions' is not null
            and ( a.api_guid is null or a.api_guid = $4 )
          ) as subs
        ) as event_json
        where event_json.sub_event_array ->> 'event' = $3
        ) as agg
      "
      retrieve_event_urls(sql, api_name, consumer_id, event, api_guid)
    end

    def self.get_observers_by_guid(api_name:, consumer_id:, api_guid:)
      uuid_regex = /^[a-f0-9]{8}-[a-f0-9]{4}-[0-5][a-f0-9]{3}-[089ab][a-f0-9]{3}-[a-f0-9]{12}$/i
      return [] unless uuid_regex.match?(consumer_id) && uuid_regex.match?(api_guid)

      sql = "
        select a.events -> 'subscriptions' as api_consumer_subscriptions
        from webhooks_subscriptions a
        where a.api_name = $1
        and a.consumer_id = $2
        and a.events -> 'subscriptions' is not null
        and a.api_guid = $3
      "
      retrieve_observers_by_guid(sql, api_name, consumer_id, api_guid)
    end

    def self.retrieve_event_urls(sql, *args)
      result = ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(sql, args).to_a
      end

      event_urls = result.first['event_urls'] ||= '[]'
      JSON.parse(event_urls).flatten.uniq
    end

    def self.retrieve_observers_by_guid(sql, *args)
      result = ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(sql, args).to_a
      end

      if result.any?
        observers = result.first['api_consumer_subscriptions']
        JSON.parse(observers)
      else
        []
      end
    end
  end
end
