# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker
    include VBADocuments

    APPEALS_CONSUMER_NAME = 'appeals_api_nod_evidence_submission'

    def perform
      if Settings.vba_documents.report_enabled
        @to = Time.zone.now
        @from = @to.monday? ? 7.days.ago : 1.day.ago
        @consumers = UploadSubmission.where(created_at: @from..@to).pluck(:consumer_name).uniq
        UnsuccessfulReportMailer.build(totals, stuck, errored, @from, @to).deliver_now
      end
    end

    def errored
      UploadSubmission.where(
        created_at: @from..@to,
        status: %w[error expired]
      ).order(:consumer_name, :status)
    end

    def stuck
      UploadSubmission.where(
        created_at: @from..@to,
        status: 'uploaded'
      ).order(:consumer_name, :status)
    end

    # rubocop:disable Metrics/MethodLength
    def totals
      ret_hash = {}
      sum_hash = UploadSubmission::RPT_STATUSES.index_with { |_v| 0; }

      @consumers.each do |name|
        counts = UploadSubmission.where(created_at: @from..@to, consumer_name: name).group(:status).count
        lobs = UploadSubmission.where(created_at: @from..@to, consumer_name: name)
                               .where("uploaded_pdf->'line_of_business' is not null")
                               .pluck("uploaded_pdf->'line_of_business'").uniq
        # put ticks around all lobs
        lobs.map! { |e| "'#{e}'" }

        # ensure that all appeals submissions have lob passed in
        if name.eql?(APPEALS_CONSUMER_NAME)
          appeals_null_lob_count = UploadSubmission.where(created_at: @from..@to, consumer_name: name)
                                                   .where("uploaded_pdf->'line_of_business' is null").count
          lobs << "#{appeals_null_lob_count} NULL" if appeals_null_lob_count.positive?
        end

        totals = counts.sum { |_k, v| v }
        error_rate = counts['error'] ? (100.0 / totals * counts['error']).round : 0
        expired_rate = counts['expired'] ? (100.0 / totals * counts['expired']).round : 0

        # sum the count of success and vbms statuses for the period
        success_count = (counts['success'] || 0) + (counts['vbms'] || 0)
        success_rate = success_count.positive? ? (100.0 / totals * success_count).round : 0

        if totals.positive?
          ret_hash[name] = counts.merge(totals: totals,
                                        success_rate: "#{success_rate}%",
                                        error_rate: "#{error_rate}%",
                                        expired_rate: "#{expired_rate}%",
                                        lobs: lobs.join(', '))

          # add the consumer counts to the summary hash for the given status
          counts.each_key do |k|
            sum_hash[k] += counts[k]
          end
        end
      end

      # get the summary total and calculate the percentages for the summary row
      sum_total = sum_hash.sum { |_k, v| v }

      if sum_total.positive?
        error_rate = "#{(100.0 / sum_total * sum_hash['error']).round}%"
        expired_rate = "#{(100.0 / sum_total * sum_hash['expired']).round}%"

        # sum the count of success and vbms statuses for the period
        success_count = sum_hash['success'] + sum_hash['vbms']
        success_rate = "#{(success_count.positive? ? (100.0 / sum_total * success_count).round : 0)}%"
        sum_hash['total'] = sum_total
        sum_hash['success_rate'] = success_rate
        sum_hash['error_rate'] = error_rate
        sum_hash['expired_rate'] = expired_rate
      else
        # report returned no rows for the given time frame so report zeros
        sum_hash['total'] = 0
        sum_hash['success_rate'] = '0%'
        sum_hash['error_rate'] = '0%'
        sum_hash['expired_rate'] = '0%'
      end

      # add the summary hash
      ret_hash['summary'] = sum_hash
      ret_hash
    end
    # rubocop:enable Metrics/MethodLength
  end
end
