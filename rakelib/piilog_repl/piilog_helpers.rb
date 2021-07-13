# frozen_string_literal: true

# rubocop:disable Metrics/BlockNesting

TimeArg = Struct.new(:time, :type, keyword_init: true)

TIME_ARGS_ARRAY_BUILDER = lambda do |array_for_collecting_time_args|
  # closure for array_for_collecting_time_args
  lambda do |arg|
    if array_for_collecting_time_args.length == 2
      raise "can only specify a start and a stop time. extra time param: #{arg.inspect}"
    end

    time_arg = case arg
               when nil
                 TimeArg.new type: :open
               when String, Symbol
                 string = arg.to_s.downcase
                 case string
                 when 'now'
                   TimeArg.new time: Time.zone.now, type: :time
                 when 'yesterday', 'today', 'tomorrow'
                   TimeArg.new time: Time.zone.send(string), type: :date
                 else
                   parsed = if string.include?(':')
                              begin
                                { time: string.in_time_zone, type: :time }
                              rescue
                                nil
                              end
                            else
                              begin
                                { time: string.to_date, type: :date }
                              rescue
                                nil
                              end
                            end
                   return false unless parsed

                   TimeArg.new(**parsed)
                 end
               else
                 if arg.respond_to?(:strftime)
                   TimeArg.new time: arg, type: arg.respond_to?(:min) ? :time : :date
                 elsif arg.is_a?(ActiveSupport::Duration)
                   TimeArg.new time: arg, type: :duration
                 else
                   return false
                 end
               end

    array_for_collecting_time_args << time_arg
    true
  end
end

TIMES_TO_WHERE_ARGS = lambda do |times|
  a, b = times.map(&:time)
  types = times.map(&:type)

  start_time, stop_time = case types
                          when [], %i[open open]
                            [nil, nil]
                          when %i[date]
                            [a.beginning_of_day, a.end_of_day]
                          when %i[duration], %i[duration open]
                            [Time.zone.now - a, nil]
                          when %i[open]
                            raise "open-ended time range wasn't completed"
                          when %i[time]
                            if a.min.zero? && a.hour.zero?
                              [a.beginning_of_day, a.end_of_day]
                            elsif a.sec != 0
                              [a.beginning_of_minute, a.end_of_minute]
                            elsif a.min.zero?
                              [a.beginning_of_hour, a.end_of_hour]
                            elsif (a.min % 5).zero?
                              [a - 5.minutes, a + 5.minutes]
                            else
                              [a - 1.minute, a + 1.minute]
                            end
                          when %i[date date]
                            [a.beginning_of_day, b.end_of_day]
                          when %i[date duration]
                            start = a.beginning_of_day
                            [start, start + b]
                          when %i[date open]
                            [a.beginning_of_day, nil]
                          when %i[date time]
                            [a.beginning_of_day, b]
                          when %i[duration date]
                            stop = b.end_of_day
                            [stop - a, stop]
                          when %i[duration duration]
                            start = Time.zone.now - a
                            [start, start + b]
                          when %i[duration time]
                            [b - a, b]
                          when %i[open date]
                            [nil, b.end_of_day]
                          when %i[open duration]
                            [nil, Time.zone.now - a]
                          when %i[open time]
                            [nil, b]
                          when %i[time date]
                            [a, b.end_of_day]
                          when %i[time duration]
                            [a, a + b]
                          when %i[time open]
                            [a, nil]
                          when %i[time time]
                            [a, b]
                          else
                            raise "unknown types: #{types.inspect}"
                          end

  result_struct = Struct.new(:args, :kwargs, keyword_init: true)

  return result_struct.new unless start_time || stop_time
  return result_struct.new args: ['created_at >= ?', start_time] unless stop_time
  return result_struct.new args: ['created_at <= ?', stop_time] unless start_time

  result_struct.new kwargs: { created_at: [start_time..stop_time] }
end

PersonalInformationLogQueryBuilder = lambda do |*args, **where_kwargs|
  query, args = if args.first.respond_to? :to_sql
                  [args.first, args[1..]]
                else
                  [PersonalInformationLog.all, args]
                end

  query = query.where(**where_kwargs) if where_kwargs.present?

  times = []
  # add_time is a lambda that takes in an arg
  # --if it's a time, adds it to times and returns true. otherwise returns false
  add_time = TIME_ARGS_ARRAY_BUILDER.call(times)

  error_class = []
  args.each do |arg|
    next if add_time.call(arg)

    case arg
    when String, Symbol
      error_class << "%#{arg}%"
    else
      raise "don't know what to do with arg: #{arg.inspect}"
    end
  end

  query = query.where('error_class ILIKE ANY (array[?])', error_class) if error_class.present?

  where_args = TIMES_TO_WHERE_ARGS.call(times)
  query = query.where(*where_args.args) if where_args.args
  query = query.where(**where_args.kwargs) if where_args.kwargs

  query
end

# rubocop:enable Metrics/BlockNesting
