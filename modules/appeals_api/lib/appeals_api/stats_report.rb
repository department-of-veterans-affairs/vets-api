# frozen_string_literal: true

module AppealsApi
  class StatsReport
    DATE_FORMAT = '%b%e, %Y'

    STATUS_TRANSITION_PAIRS = [
      %w[processing submitted], %w[submitted complete], %w[processing success], %w[error success]
    ].freeze

    STALLED_RECORD_MONTHS = (3..6)

    def initialize(date_from, date_to)
      @date_from = date_from
      @date_to = date_to
    end

    def text
      <<~REPORT
        Appeals stats report
        #{date_from.strftime(DATE_FORMAT)} to #{date_to.strftime(DATE_FORMAT)}
        ===

        Higher Level Reviews
        ---
        ### Transition times

        #{formatted_timespan_stats(AppealsApi::HigherLevelReview)}
        ### Stalled records

        #{formatted_stalled_stats(AppealsApi::HigherLevelReview)}


        Notice of Disagreements
        ---
        ### Transition times

        #{formatted_timespan_stats(AppealsApi::NoticeOfDisagreement)}
        ### Stalled records

        #{formatted_stalled_stats(AppealsApi::NoticeOfDisagreement)}


        Supplemental Claims
        ---
        ### Transition times

        #{formatted_timespan_stats(AppealsApi::SupplementalClaim)}
        ### Stalled records

        #{formatted_stalled_stats(AppealsApi::SupplementalClaim)}
      REPORT
    end

    private

    attr_accessor :date_from, :date_to

    def status_update_records(statusable_type, status_from, status_to)
      @records ||= {}
      @records[statusable_type] ||= {}
      @records[statusable_type][status_from] ||= {}
      @records[statusable_type][status_from][status_to] ||=
        begin
          records = AppealsApi::StatusUpdate.where(
            from: status_from,
            to: status_to,
            statusable_type:,
            status_update_time: date_from..date_to
          ).order(:statusable_id).select('distinct on (statusable_id) *')

          previous_records = AppealsApi::StatusUpdate.where(
            to: status_from,
            statusable_id: records.pluck(:statusable_id),
            statusable_type:
          ).where.not(from: status_from).order(:statusable_id).select('distinct on (statusable_id) *')

          # filter out records with no matching previous record
          records = records.where(statusable_id: previous_records.pluck(:statusable_id))

          records.to_a.zip(previous_records.to_a)
        end
    end

    def stats(update_record_pairs)
      return { mean: nil, median: nil } if update_record_pairs.empty?

      sum, values = update_record_pairs.reduce([0, []]) do |(s, v), (current, previous)|
        timespan = current.status_update_time - previous.status_update_time
        [s + timespan, v << timespan]
      end

      values.sort!
      middle = (values.count - 1) / 2.0

      {
        mean: sum / values.count,
        median: (values[middle.floor] + values[middle.ceil]) / 2.0
      }
    end

    def timespan_in_words(seconds)
      return '(none)' if seconds.nil?

      minutes, = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)
      days, hours = hours.divmod(24)

      "#{days}d #{hours}h #{minutes}m"
    end

    def formatted_timespan_stats(appeal_class)
      parts = STATUS_TRANSITION_PAIRS.map do |(status_from, status_to)|
        values = stats(status_update_records(appeal_class.name, status_from, status_to))

        <<~STATS
          From '#{status_from}' to '#{status_to}':
          * Average: #{timespan_in_words(values[:mean])}
          * Median:  #{timespan_in_words(values[:median])}
        STATS
      end

      parts.join("\n")
    end

    def stalled_records(appeal_class, status)
      @stalled ||= {}
      @stalled[appeal_class.name] ||= {}
      @stalled[appeal_class.name][status] ||= appeal_class.where(
        'updated_at < ?',
        (date_to - STALLED_RECORD_MONTHS.first.months).beginning_of_day
      ).where(status:).order(updated_at: :desc)
    end

    def formatted_stalled_stats(appeal_class)
      parts = STATUS_TRANSITION_PAIRS.collect(&:first).uniq.map do |status|
        stalled = stalled_records(appeal_class, status).to_a

        unless stalled.empty?
          counts = {}
          lines = ["Stalled in '#{status}':"]

          STALLED_RECORD_MONTHS.each do |num|
            if num == STALLED_RECORD_MONTHS.last
              counts["> #{num} months:"] = stalled.count
            else
              matches, stalled = stalled.partition { |r| r.updated_at > date_to - (num + 1).months }
              counts["#{num}-#{num + 1} months:"] = matches.count
            end
          end

          counts.each { |label, value| lines << "* #{label} #{value}" unless value.zero? }
          lines.join("\n")
        end
      end.compact

      parts.empty? ? '(none)' : parts.join("\n")
    end
  end
end
