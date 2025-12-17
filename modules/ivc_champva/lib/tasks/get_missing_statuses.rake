# frozen_string_literal: true

namespace :ivc_champva do
  desc 'Get form UUIDs with missing pega_status (outputs comma-separated list for use in FORM_UUIDS)'
  task get_missing_statuses: :environment do
    silent = ENV['SILENT'] == 'true'

    unless silent
      puts '=' * 80
      puts 'IVC CHAMPVA GET MISSING PEGA STATUS UUIDs'
      puts '=' * 80
      puts 'Getting forms with missing pega_status...'
      puts '-' * 80
    end

    cleanup_util = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new
    batches = cleanup_util.get_missing_statuses(silent: true, ignore_last_minute: true)

    if batches.empty?
      puts 'No forms found.' unless silent
    else
      form_uuids = batches.keys
      total_forms = batches.values.sum(&:count)

      puts "Found #{total_forms} forms with missing pega_status" unless silent

      unless silent
        puts "Grouped into #{batches.count} unique form submissions (UUIDs)"
        puts "\nForm UUIDs with missing pega_status:"
        puts '-' * 120
        printf "%-40<form_uuid>s %-20<s3_status>s %-25<created_at>s %<form_count>s\n",
               { form_uuid: 'FORM_UUID', s3_status: 'S3_STATUS', created_at: 'CREATED_AT', form_count: 'FORM_COUNT' }
        puts '-' * 120

        form_uuids.each do |uuid|
          batch = batches[uuid]
          representative_form = batch.first
          form_count = batch.count
          s3_statuses = batch.pluck(:s3_status).uniq.join(', ')
          created_at = representative_form.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')

          printf "%-40<form_uuid>s %-20<s3_status>s %-25<created_at>s %<form_count>d\n",
                 { form_uuid: uuid, s3_status: s3_statuses, created_at:, form_count: }
        end

        puts "\nComma-separated list for FORM_UUIDS variable:"
        puts '-' * 50
      end

      puts form_uuids.join(',')
    end
  end
end
