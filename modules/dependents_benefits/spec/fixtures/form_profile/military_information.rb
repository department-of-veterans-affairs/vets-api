# frozen_string_literal: true

module MilitaryInformationSpecData
  def self.initialize_va_profile_prefill_military_information_expected
    {
      'currently_active_duty' => false,
      'currently_active_duty_hash' => { yes: false },
      'discharge_type' => nil,
      'guard_reserve_service_history' => guard_reserve_service_history,
      'hca_last_service_branch' => 'army',
      'last_discharge_date' => '2018-10-31',
      'last_entry_date' => '2012-03-02',
      'last_service_branch' => 'Army',
      'latest_guard_reserve_service_period' => { from: '2012-03-02', to: '2018-10-31' },
      'post_nov111998_combat' => false,
      'service_branches' => %w[A N],
      'service_episodes_by_date' => service_episodes_by_date,
      'service_periods' => service_periods,
      'sw_asia_combat' => false,
      'tours_of_duty' => tours_of_duty
    }
  end

  def self.service_episodes_by_date
    [
      service_episode2012,
      service_episode2009,
      service_episode2002
    ]
  end

  def self.guard_reserve_service_history
    [{ from: '2012-03-02', to: '2018-10-31' },
     { from: '2009-03-01', to: '2012-12-31' },
     { from: '2002-02-02', to: '2008-12-01' }]
  end

  def self.service_periods
    [
      { service_branch: 'Army National Guard', date_range: { from: '2012-03-02', to: '2018-10-31' } },
      { service_branch: 'Army National Guard', date_range: { from: '2002-02-02', to: '2008-12-01' } }
    ]
  end

  def self.tours_of_duty
    [
      { service_branch: 'Army', date_range: { from: '2002-02-02', to: '2008-12-01' } },
      { service_branch: 'Navy', date_range: { from: '2009-03-01', to: '2012-12-31' } },
      { service_branch: 'Army', date_range: { from: '2012-03-02', to: '2018-10-31' } }
    ]
  end

  def self.service_episode2012
    {
      begin_date: '2012-03-02',
      branch_of_service: 'Army',
      branch_of_service_code: 'A',
      character_of_discharge_code: nil,
      deployments: [],
      end_date: '2018-10-31',
      period_of_service_type_code: 'N',
      period_of_service_type_text: 'National Guard member',
      service_type: 'Military Service',
      termination_reason_code: 'C',
      termination_reason_text: 'Completion of Active Service period'
    }
  end

  def self.service_episode2009
    {
      begin_date: '2009-03-01',
      branch_of_service: 'Navy',
      branch_of_service_code: 'N',
      character_of_discharge_code: nil,
      deployments: [],
      end_date: '2012-12-31',
      period_of_service_type_code: 'N',
      period_of_service_type_text: 'National Guard member',
      service_type: 'Military Service',
      termination_reason_code: 'C',
      termination_reason_text: 'Completion of Active Service period'
    }
  end

  def self.service_episode2002
    {
      begin_date: '2002-02-02',
      branch_of_service: 'Army',
      branch_of_service_code: 'A',
      character_of_discharge_code: nil,
      deployments: [],
      end_date: '2008-12-01',
      period_of_service_type_code: 'N',
      period_of_service_type_text: 'National Guard member',
      service_type: 'Military Service',
      termination_reason_code: 'C',
      termination_reason_text: 'Completion of Active Service period'
    }
  end
end
