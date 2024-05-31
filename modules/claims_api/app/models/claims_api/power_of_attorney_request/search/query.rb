# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    module Search
      module Query
        module Filter
          module Decision
            module Statuses
              ALL = [
                NONE = 'None',
                ACCEPTED = PowerOfAttorneyRequest::Decision::Statuses::ACCEPTED,
                DECLINED = PowerOfAttorneyRequest::Decision::Statuses::DECLINED
              ].freeze
            end
          end
        end

        module Page
          # These values currently duplicate the behavior of BGS, but they can
          # be changed so long as:
          #   bgs_min <= min
          #   max <= bgs_max
          #   min <= default <= max
          module Size
            DEFAULT = 25
            MAX = 100
            MIN = 1
          end
        end

        module Sort
          module Fields
            ALL = [
              CREATED_AT = 'createdAt'
            ].freeze
          end

          module Orders
            ALL = [
              ASCENDING = 'asc',
              DESCENDING = 'desc'
            ].freeze
          end
        end

        class << self
          def dump(query, xml, data_aliaz) # rubocop:disable Metrics/MethodLength
            filter = query[:filter]

            xml[data_aliaz].SecondaryStatusList do
              statuses = filter.dig(:decision, :statuses)
              statuses.each do |status|
                case status
                when Filter::Decision::Statuses::NONE
                  xml.SecondaryStatus('New')
                  xml.SecondaryStatus('Pending')
                else
                  xml.SecondaryStatus(status)
                end
              end
            end

            xml[data_aliaz].POACodeList do
              filter[:poaCodes].each do |poa_code|
                xml.POACode(poa_code)
              end
            end

            xml[data_aliaz].POARequestParameter do
              page = query[:page]
              xml.pageIndex(page[:number])
              xml.pageSize(page[:size])

              sort = query[:sort]
              xml.poaSortField(
                case sort[:field]
                when Sort::Fields::CREATED_AT
                  'DATE_RECEIVED'
                else
                  raise <<~MSG.squish
                    unknown sort field:
                    #{sort[:field]}
                  MSG
                end
              )

              xml.poaSortOrder(
                case sort[:order]
                when Sort::Orders::ASCENDING
                  'ASCENDING'
                when Sort::Orders::DESCENDING
                  'DESCENDING'
                else
                  raise <<~MSG.squish
                    unknown sort order:
                    #{sort[:order]}
                  MSG
                end
              )
            end
          end
        end
      end
    end
  end
end
