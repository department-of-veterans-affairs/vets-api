# frozen_string_literal: true

# rubocop:disable  Metrics/ModuleLength
module VBADocuments
  module SQLSupport
    STATUS_ELAPSED_TIME = %(
      select status,
      min(duration) as min_secs,
      max(duration) as max_secs,
      round(avg(duration))::integer as avg_secs,
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
          where created_at > $1 and created_at < $2
          CONSUMER_NAME_PART
        ) as n1
        where status_json -> status_key -> 'end' is not null
      ) as closed_statuses
      group by status
    )

    # monthly report SQL start
    MONTHLY_COUNT_SQL = "
      select
        to_char(created_at, 'YYYYMM') as yyyymm,
        consumer_name,
        sum(case when status = 'error' then 1 else 0 end) as errored,
        sum(case when status = 'expired' then 1 else 0 end) as expired,
        sum(case when status = 'pending' or status = 'uploaded' or
            status = 'received' or status = 'processing' then 1 else 0 end) as processing,
        sum(case when status = 'success' then 1 else 0 end) as success,
        sum(case when status = 'vbms' then 1 else 0 end) as vbms,
        count(*) as total
      from vba_documents_upload_submissions a
      where a.created_at >= $1 and a.created_at < $2
      group by to_char(created_at, 'YYYYMM'), a.consumer_name
      order by to_char(created_at, 'YYYYMM') asc, a.consumer_name asc
    "

    PROCESSING_SQL = "
      select a.consumer_name, a.guid, a.status, a.created_at, a.updated_at
      from vba_documents_upload_submissions a
      where a.status in ('uploaded','received', 'processing','pending')
      and   a.updated_at < $1
      order by a.consumer_name asc
    "

    SUCCESS_SQL = "
      select a.consumer_name, a.guid, a.status, a.created_at, a.updated_at
      from vba_documents_upload_submissions a
      where a.status = 'success'
      and   a.created_at >= $1 and a.created_at < $2
      and   a.metadata -> 'final_success_status' is null
      order by a.consumer_name, a.created_at asc
    "

    MAX_AVG_SQL = "
      select yyyy, mm,
        NULLIF(sum(max_pages)::integer,0) as max_pages, NULLIF(sum(avg_pages)::integer,0) as avg_pages,
        NULLIF(sum(max_size)::bigint,0) as max_size, NULLIF(sum(avg_size)::bigint,0) as avg_size
      from (
      ( select
        date_part('year', a.created_at)::integer as yyyy,
        date_part('month', a.created_at)::integer as mm,
        max((uploaded_pdf->>'total_pages')::integer) as max_pages,
        round(avg((uploaded_pdf->>'total_pages')::integer))::integer as avg_pages,
        0::bigint as max_size,
        0::bigint as avg_size
      from vba_documents_upload_submissions a
      where a.uploaded_pdf is not null
      and   a.status != 'error'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
      )
    union
      ( select
        date_part('year', a.created_at)::integer as yyyy,
        date_part('month', a.created_at)::integer as mm,
        0::integer as max_pages,
        0::integer as avg_pages,
        max((metadata->'size')::bigint) as max_size_bytes,
        round(avg((metadata->'size')::bigint))::bigint as avg_size_bytes
      from vba_documents_upload_submissions a
      where a.metadata->'size' is not null
      and   a.status != 'error'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
      )
    ) as max_avg
    group by 1,2
    order by 1 desc, 2 desc
    "

    MODE_SQL = "
    select yyyy, mm, NULLIF(sum(mode_pages)::integer,0) as mode_pages, NULLIF(sum(mode_size)::bigint,0) as mode_size
    from (
        ( select
          date_part('year', a.created_at)::integer as yyyy,
          date_part('month', a.created_at)::integer as mm,
          mode() within group (order by (uploaded_pdf->>'total_pages')::integer) as mode_pages,
          0::bigint as mode_size
        from vba_documents_upload_submissions a
        where a.uploaded_pdf is not null
        and   a.status != 'error'
        and   a.created_at < $1
        group by 1,2
        order by 1 desc, 2 desc
        limit 12 )
      union
        ( select
            date_part('year', a.created_at)::integer as yyyy,
            date_part('month', a.created_at)::integer as mm,
            0::integer as mode_pages,
            mode() within group (order by (metadata->>'size')::bigint) as mode_size
          from vba_documents_upload_submissions a
          where a.metadata is not null
          and   a.status != 'error'
          and   a.created_at < $1
          group by 1,2
          order by 1 desc, 2 desc
          limit 12
        )
    ) as mode_results
    group by 1,2
    order by 1 desc, 2 desc
    "

    MONTHLY_TIME_BETWEEN_STATUSES_SQL = "
      select count(*) as rowcount, min(duration)::integer as min_bt_status,
        avg(duration)::integer as avg_bt_status, max(duration)::integer as max_bt_status
      from (
        SELECT (metadata -> 'status' -> $3 -> 'start')::bigint -
                (metadata -> 'status' -> $2 -> 'start')::bigint as duration
        from vba_documents_upload_submissions
        where to_char(created_at,'yyyymm') = $1
        and   (metadata -> 'status' -> $2 -> 'start') is not null
        and   (metadata -> 'status' -> $3 -> 'start') is not null
      ) as n1
	  "

    MEDIAN_ELAPSED_TIME_SQL = "
    select duration as median_secs
    from (
      select status_key as status,
        (status_json -> status_key -> 'end')::INTEGER - (status_json -> status_key -> 'start')::INTEGER as duration
      from (
          SELECT jsonb_object_keys(metadata -> 'status') as status_key, metadata -> 'status' as status_json
          from vba_documents_upload_submissions
          where to_char(created_at,'yyyymm') = $1
        ) as n1
      where status_json -> status_key -> 'end' is not null
      and   status_key = $2
      ) as closed_statuses
      order by duration asc
      offset(
        select count(*)/2
        from (
          SELECT guid,
          jsonb_object_keys(metadata -> 'status') as status_key,
          metadata -> 'status' as status_json
          from vba_documents_upload_submissions
          where to_char(created_at,'yyyymm') = $1
        ) as n1
        where status_json -> status_key -> 'end' is not null
        and   status_key = $2
      )
      limit 1
    "

    MEDIAN_SQL = "
      select NULLIF(sum(median_pages)::integer,0) as median_pages, NULLIF(sum(median_size)::bigint,0) as median_size
      from (
        (select (uploaded_pdf->>'total_pages')::integer as median_pages, 0::bigint as median_size
        from vba_documents_upload_submissions a
        where a.uploaded_pdf is not null
        and   a.status != 'error'
        and   to_char(a.created_at,'yyyymm') = $1
        order by (uploaded_pdf->>'total_pages')::bigint
        offset (select count(*) from vba_documents_upload_submissions
        where uploaded_pdf is not null
        and   status != 'error'
        and   to_char(created_at,'yyyymm') = $1)/2
        limit 1)
        UNION
        (select 0::integer as median_pages, (metadata->>'size')::bigint as median_size
        from vba_documents_upload_submissions a
        where a.metadata is not null
        and   a.status != 'error'
        and   to_char(a.created_at,'yyyymm') = $1
        order by (metadata->>'size')::bigint
        offset (select count(*) from vba_documents_upload_submissions
        where metadata->>'size' is not null
        and   status != 'error'
        and   to_char(created_at,'yyyymm') = $1)/2
        limit 1)
      ) as median_results
    "

    MONTHLY_GROUP_SQL = "
      select
      date_part('year', a.created_at)::integer as yyyy,
      date_part('month', a.created_at)::integer as mm,
      count(*) as count
      from vba_documents_upload_submissions a
      where a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
    "
    # monthly report SQL end

    def status_elapsed_time_sql(consumer_name = nil)
      sql_part = consumer_name ? "and consumer_name = '#{consumer_name}' " : ''
      STATUS_ELAPSED_TIME.sub('CONSUMER_NAME_PART', sql_part)
    end
  end
end
# rubocop:enable  Metrics/ModuleLength
