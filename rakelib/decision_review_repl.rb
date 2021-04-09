# frozen_string_literal: true

# run this with:  bin/rails runner rakelib/decision_review_repl.rb

# rubocop:disable Lint/ShadowingOuterLocalVariable
# rubocop:disable Style/MultilineBlockChain

require_relative 'piilog_repl/piilog_helpers.rb'

alias _p p
alias _pp pp

def info_string
  <<~INFO

    # example: get the PersonalInformationLogs for HLR for the past week

    logs = Q.(:hlr, 7.days)     # returns a PersonalInformationLog relation

    # Q is the PersonalInformationLogQueryBuilder --a lambda that makes it easier to query PersonalInformationLog.

    # It returns a relation:

    logs = Q.(:hlr, :nod).where('updated_at > ?' Time.zone.yesterday)   #  that's hlr /or/ nod exceptions

    # PersonalInformationLogs are hard to wrangle because so much gets dumped into its 'data' attribute.

    # There are a handful of PersonalInformationLog "wrapper classes" that add handy methods depending on
    # the type of PersonalInformationLog (PiiLogs recorded in the controller as opposed to the service,
    # for instance). Scroll down to look through them and what they offer, /BUT/, you do *not* need to
    # explicitly call them. The wrap command will take a PersonalInformationLog (or Logs) and wrap each
    # one with the appropriate wrapper class. You end up with an array of PersonalInformationLog objects,
    # that still work just like PersonalInformationLog objects should, but, if the PiiLog was recorded in
    # the controller, for example, it will have user info helper methods, if it was recorded near where
    # the response gets tested against the schema, it will have schema helper methods and so on.

    logs = wrap logs    # returns an array with helper methods added to each PersonalInformationLog
                        # depending on its type (was it thrown in a controller, the service, etc.)


    # There are a slew of methods that work with an array of wrapped PiiLogs.

    # for instance:

    hash = by_error_message_category(wrap(Q.(:hlr, :yesterday))) # notice the "wrap" nestled in there

    # this will return a hash that organizes the array of PiiLogs by their error message category

    # if you pretty print it, it will look something like:

    p hash

    {"Outage..."=>
      [#<PersonalInformationLog:0x0000000000000000
        id: 0000000,
        data:
         {"user"=>
           {"icn"=> ...
            "ssn"=> ...
     "Timeout"=> ...



    # see "spec/rakelib/piilog_repl/piilog_helpers_spec.rb" for more examples of using
    # the PersonalInformationLogQueryBuilder



    # MISC:

    # When a single time is specified (only 1 time arg that is a time not a date), there are a few
    # special rules to get handy intervals --some examples:
    # If the current second is non-zero you get the time range of the beginning of the current min
    # to the end of the current minute.
    # If the current second is zero, you get a time range of -1 min -> +1 min for the current min
    # ... and so on .. see TIMES_TO_WHERE_ARGS for the full rule set for how time arguments are
    # interpreted.

  INFO
end

def info
  puts info_string
end

def recipes_string
  <<~RECIPES

    #############     type 'info' for more info
    #  RECIPES  #
    #############



    # /\\ get an HLR piilog that
    # \\/  was just now logged:

    logs = Q.(:hlr, :now)   # this will give you the time range of the current minute.
                            # beside timestamp strings you can use :now, :today, :yesterday,
                            # :tomorrow as well as any time/date obj




    # /\\  get the error counts for the
    # \\/   last week of NOD errors


    # print the error counts by category:

      puts_by_error_message_category_counts wrap Q.(:nod, 7.days)

      #  {"Gateway timeout"=>7,
      #   "BackendServiceException [DR_422]"=>7,
      #   "Outage..."=>6,
      #   "BackendServiceException [DR_404]"=>2,
      #   "BackendServiceException [unmapped_service_exception]"=>1}

    # print the same counts, but first organize by where the exception occurred

      puts_by_error_class_counts wrap Q.(:nod, 7.days)

      #  {"V0::HigherLevelReviews::ContestableIssuesController#index exception Common::Exceptions::GatewayTimeout (HLR)"=>
      #    {"Gateway timeout"=>7},
      #   "V0::HigherLevelReviewsController#create exception DecisionReview::ServiceException (HLR)"=>
      #    {"BackendServiceException [DR_422]"=>7},
      #   "V0::HigherLevelReviews::ContestableIssuesController#index exception Breakers::OutageException (HLR)"=>
      #    {"Outage..."=>4},
      #   "V0::HigherLevelReviews::ContestableIssuesController#index exception DecisionReview::ServiceException (HLR)"=>
      #    {"BackendServiceException [DR_404]"=>2,
      #     "BackendServiceException [unmapped_service_exception]"=>1},
      #   "V0::HigherLevelReviewsController#create exception Breakers::OutageException (HLR)"=>
      #    {"Outage..."=>2}}

    # now you can see that some of those 6 outages occurred at the ContestableIssuesController#index and
    # some at HigherLevelReviewsController#create.




    # /\\ get the error counts for
    # \\/  the past 14 days

    14.downto(1).each do |d|
      date = (Time.zone.now - d.days).to_date
      count = Q.(:hlr, :nod, date).count
      puts "%s  %s %3d" % [date.strftime('%A')[0..2], date, count]
    end



    (type 'info' for more info)

  RECIPES
end

def recipes
  puts recipes_string
end

# Ruby pretty print that doesn't echo the value after pretty printing it
def p(object)
  _pp object
  nil
end

# pretty print using pretty_generate
def pp(object)
  puts JSON.pretty_generate object
end

# recurses through a hash and, anytime an array is encountered, it's replaced with its count
def counts(hash)
  hash.reduce({}) do |acc, (k, v)|
    count = case v
            when Array
              v.count
            when Hash
              counts(v)
            else
              v
            end
    acc.merge k => count
  end.sort_by do |_k, v|
    -(v.is_a?(Hash) ? total_in_tree(v) : v)
  end.to_h
end

# given a hash, or subhash, adds up all of the integers encountered (recursive)
def total_in_tree(hash)
  hash.reduce(0) do |acc, (_k, v)|
    acc + case v
          when Array, Hash
            total_in_tree v
          else
            v.is_a?(Integer) ? v : 0
          end
  end
end

# PersonalInformationLog wrapper
class PiiLog < SimpleDelegator
  def error
    data['error']
  end

  def error_message
    error&.send(:[], 'message').to_s
  end

  def error_message_category
    if error_message.starts_with? 'Outage detected on DecisionReview beginning at'
      'Outage...'
    elsif error_message.starts_with? 'BackendServiceException: {:'
      match = error_message.match(/:code=>"(?<code>.*?)"/)
      if match
        code = match[:code]
        "BackendServiceException [#{code}]"
      else
        error_message
      end
    else
      error_message
    end
  end

  def helper_methods
    puts (methods - PersonalInformationLog.instance_methods - SimpleDelegator.instance_methods).sort
  end
end

# When using a PersonalInformationLog, everything pretty much gets dumped into 'data'.
# The shape of 'data' depends on where in the code a PersonalInformationLog is being created.
# The following classes help wrangle these deep hashes.
# When you use 'new' with the following classes (and pass in a PersonalInformationLog)
# what you get back out is still a PersonalInformationLog, just with some added helper methods.

# Wrapper for PersonalInformationLogs created from DecisionReview controller exceptions
# PersonalInformationLog wrapper
class ControllerException < PiiLog
  def user_ids
    data['user']
  end

  def user_id
    # user_ids.values.reduce('') { |acc, id| acc + (id ? id.to_s : '|') }
    user_ids.values.join('|')
  end

  def errors
    error['errors']
  end

  def backtrace
    error['backtrace']
  end
end

# for HigherLevelReviewsController#create
# and NoticeOfDisagreementsController#create
# PersonalInformationLog wrapper
class ControllerCreateException < ControllerException
  def body
    data.dig('additional_data', 'request', 'body')
  end

  def lighthouse_response
    data.dig('error', 'original_body')
  end
end

# PersonalInformationLog wrapper
class HlrContestableIssuesControllerIndexException < ControllerException
  def benefit_type
    data['additional_data']['benefit_type']
  end
end

# PersonalInformationLog wrapper
class GetContestableIssuesSchemaValidationError < PiiLog
  def json
    data['json']
  end

  def lighthouse_response
    json
  end

  def schema
    data['schema']
  end

  def errors
    data['errors']
  end

  def contestable_issues
    data.dig('json', 'data')
  end

  def data_pointers
    errors.map { |schema_error| schema_error['data_pointer'] }
  end

  def local_schemas
    errors.map { |schema_error| schema_error['schema'] }
  end
end

# given a PersonalInformationLog, picks the correct wrapper class
def wrap_personal_information_log(value, raise_if_no_suitable_wrapper_found: true)
  case
  when value.data.dig('schema', 'properties', 'data', 'items', 'properties', 'type', 'enum', 0) == 'contestableIssue'
    GetContestableIssuesSchemaValidationError
  when value.error_class.include?('HigherLevelReviews::ContestableIssuesController#index exception')
    HlrContestableIssuesControllerIndexException
  when value.error_class.include?('ContestableIssuesController#index exception')
    ControllerException
  when value.error_class.include?('HigherLevelReviewsController#create exception')
    ControllerCreateException
  when raise_if_no_suitable_wrapper_found
    raise "couldn't find a suitable wrapper for #{value.inspect}"
  else
    return value
  end.new value
end

# takes a PersonalInformationLog relation and returns an array of wrapped PersonalInformationLogs
def wrap_personal_information_logs(relation)
  relation.map do |personal_information_log|
    wrap_personal_information_log personal_information_log
  end
end

def wrap(value)
  if value.is_a?(PersonalInformationLog)
    wrap_personal_information_log value
  else
    wrap_personal_information_logs value
  end
end

# the following methods take an array of wrapped-PersonalInformationLogs
def by_error_class(array)
  new_hash = Hash.new do |hash, key|
    hash[key] = Hash.new { |hash, key| hash[key] = [] }
  end

  array.each do |piilog|
    new_hash[piilog.error_class][piilog.error_message_category] << piilog
  end

  new_hash
end

def by_error_message_category(array)
  new_hash = Hash.new { |hash, key| hash[key] = [] }

  array.each do |piilog|
    new_hash[piilog.error_message_category] << piilog
  end

  new_hash
end

def puts_by_error_class(array)
  p by_error_class array
end

def by_error_class_counts(array)
  counts by_error_class array
end

def puts_by_error_class_counts(array)
  p counts by_error_class array
end

def puts_by_error_message_category(array)
  p by_error_message_category array
end

def by_error_message_category_counts(array)
  counts by_error_message_category array
end

def puts_by_error_message_category_counts(array)
  p counts by_error_message_category array
end

Q = PersonalInformationLogQueryBuilder
puts recipes
pry

# rubocop:enable Lint/ShadowingOuterLocalVariable
# rubocop:enable Style/MultilineBlockChain
