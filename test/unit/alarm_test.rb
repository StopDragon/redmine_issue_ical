# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AlarmTest < ActiveSupport::TestCase
  Alarm = RedmineIssueIcal::Alarm

  def trigger(label, all_day: false)
    Alarm.parse(label)&.trigger(all_day: all_day)
  end

  test 'korean labels become triggers relative to the start' do
    assert_equal 'TRIGGER:PT0S', trigger('정시')
    assert_equal 'TRIGGER:-PT1M', trigger('1분 전')
    assert_equal 'TRIGGER:-PT30M', trigger('30분 전')
    assert_equal 'TRIGGER:-PT2H', trigger('2시간 전')
    assert_equal 'TRIGGER:-P1D', trigger('1일 전')
    assert_equal 'TRIGGER:-P1W', trigger('1주 전')
    assert_equal 'TRIGGER:-P1D', trigger('1일전')
  end

  test 'end labels are relative to the end' do
    assert_equal 'TRIGGER;RELATED=END:-PT10M', trigger('끝나기 10분 전')
    assert_equal 'TRIGGER;RELATED=END:-PT10M', trigger('10 minutes before end')
  end

  test 'english labels' do
    assert_equal 'TRIGGER:PT0S', trigger('At time of event')
    assert_equal 'TRIGGER:-PT15M', trigger('15 minutes before')
    assert_equal 'TRIGGER:-PT1H', trigger('1 hour before')
    assert_equal 'TRIGGER:-P2D', trigger('2 days before')
  end

  test 'all-day events count from 09:00' do
    assert_equal 'TRIGGER:PT9H', trigger('정시', all_day: true)
    assert_equal 'TRIGGER:PT8H30M', trigger('30분 전', all_day: true)
    assert_equal 'TRIGGER:-PT15H', trigger('1일 전', all_day: true)
    assert_equal 'TRIGGER:-P6DT15H', trigger('1주 전', all_day: true)
    assert_equal 'TRIGGER;RELATED=END:-PT15H10M', trigger('끝나기 10분 전', all_day: true)
  end

  test 'none labels mean no alarm' do
    assert Alarm.parse('없음').none?
    assert Alarm.parse('None').none?
    assert_not Alarm.parse('정시').none?
  end

  test 'other values are not alarms' do
    [nil, '', 'soon', '10분 후'].each { |label| assert_nil Alarm.parse(label), label.inspect }
  end
end
