# frozen_string_literal: true

module VBADocuments
  module SQLSupport
    AVG_STATUS = %(
      select status,
      round(avg(duration)) as elapsed_secs,
    	count(*) as rowcount
      from (
        select guid,
          status_key as status,
          consumer_name,
          created_at,
          status_json -> status_key -> 'start' as start_time,
          status_json -> status_key -> 'end' as end_time,
          (status_json -> status_key -> 'end')::INTEGER -
            (status_json -> status_key -> 'start')::INTEGER as duration
        from (
          SELECT guid,
            consumer_name,
            created_at,
            jsonb_object_keys(metadata -> 'status') as status_key,
            metadata -> 'status' as status_json
          from vba_documents_upload_submissions
        ) as n1
        where status_json -> status_key -> 'end' is not null
      ) as closed_statuses
      where 1 = 1
      CONSUMER_NAME_PART
      and   created_at > $1 and created_at < $2
      group by status
    )
    def avg_sql(consumer_name = nil)
      sql_part = consumer_name ? "and consumer_name = '#{consumer_name}' " : ''
      AVG_STATUS.sub('CONSUMER_NAME_PART', sql_part)
    end
  end
end
