# frozen_string_literal: true

require_relative 'example_definition'
require_relative 'vcr_matchers'

module SubmitAllClaimSpec
  module Helper
    extend ActiveSupport::Concern

    class_methods do
      def define_example(description, &)
        definition = ExampleDefinition.build!(&)

        it description do
          definition.before and instance_exec(&definition.before)
          user = build(:user, :loa3, icn: definition.user_icn)
          sign_in_as(user)

          cassette_path = CASSETTE_PATH_PREFIX / description
          payload_fixture_path = PAYLOAD_FIXTURE_PATH_PREFIX / "#{definition.payload_fixture}.json"

          VCR.use_cassette(cassette_path, VCR_OPTIONS) do
            Sidekiq::Testing.inline! do
              body = File.read(payload_fixture_path)
              post(:submit_all_claim, body:, as: :json)

              self.class.resurface_exceptions!(parsed_response)
              expect(response).to have_http_status(:ok)
            end
          end

          if definition.assert
            submission = self.class.get_submission(parsed_response)
            instance_exec(submission, &definition.assert)
          end
        end
      end

      def get_submission(parsed_response)
        where_clause = {
          form526_job_statuses: {
            job_id: parsed_response.dig('data', 'attributes', 'job_id'),
            job_class: 'SubmitForm526AllClaim'
          }
        }

        Form526Submission
          .joins(:form526_job_statuses)
          .where(where_clause)
          .sole
      end

      ##
      # TODO: Explain this.
      #
      def resurface_exceptions!(parsed_response)
        meta = parsed_response.dig('errors', 0, 'meta').to_h
        exception, stacktrace = meta.values_at('exception', 'backtrace')
        return unless exception

        io = StringIO.new
        io.puts 'Exception:'
        io.puts exception

        if stacktrace
          io.puts
          io.puts 'Backtrace:'
          stacktrace.grep(/vets-api/).each do |location|
            io.puts location
          end
        end

        raise io.string
      end
    end

    def parsed_response
      @parsed_response ||= JSON.parse(response.body)
    end

    VCR_OPTIONS = {
      record: :once, allow_unused_http_interactions: false,
      match_requests_on: [VcrMatchers.build].freeze
    }.freeze

    PATH_PREFIX = Pathname('disability_compensation_form/submit_all_claim')
    PAYLOAD_FIXTURE_PATH_PREFIX = Pathname('spec/support') / PATH_PREFIX
    CASSETTE_PATH_PREFIX = PATH_PREFIX
    #
    # `VCR::Configuration#cassette_library_dir` is prepended.
    ##

    ARTIFICIAL_TOGGLE_VALUES = {
      disability_526_send_form526_submitted_email: true,
      disability_compensation_fail_submission: false,
      disability_compensation_prevent_submission_job: false,
      disability_compensation_production_tester: false,
      disability_compensation_upload_0781_to_lighthouse: true,
      disability_compensation_upload_bdd_instructions_to_lighthouse: true,
      disability_compensation_use_api_provider_for_bdd_instructions: true
    }.freeze

    included do
      before do
        ##
        # TODO: Explain this.
        #
        ARTIFICIAL_TOGGLE_VALUES.each do |toggle, value|
          [toggle.to_sym, toggle.to_s].each do |t|
            allow(Flipper).to(
              receive(:enabled?).with(t, any_args).and_return(value)
            )
          end
        end
      end
    end
  end
end
