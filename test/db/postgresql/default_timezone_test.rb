require 'test_helper'
require 'db/postgres'

class PostgresDefaultTimezoneTest < Test::Unit::TestCase

  def setup
    @orig_tz = java.util.TimeZone.getDefault
    @orig_default = ActiveRecord.default_timezone
  end

  def teardown
    java.util.TimeZone.setDefault(@orig_tz)
    ActiveRecord.default_timezone = @orig_default
    connection.select_value('SELECT 1') # re-sync session zone
  end

  def test_session_zone_follows_default_timezone_at_runtime
    ActiveRecord.default_timezone = :utc
    assert_equal 'UTC', session_zone

    ActiveRecord.default_timezone = :local
    set_process_zone 'Asia/Tokyo'
    assert_equal 'Asia/Tokyo', session_zone

    # symbol stays :local, only the zone changes
    set_process_zone 'America/New_York'
    assert_equal 'America/New_York', session_zone

    ActiveRecord.default_timezone = :utc
    assert_equal 'UTC', session_zone
  end

  def test_bound_timestamp_keeps_instant_when_local
    ActiveRecord.default_timezone = :local
    set_process_zone 'Asia/Tokyo'
    time = Time.utc(2026, 1, 1, 0, 0, 0)
    sql = 'SELECT ?::timestamptz = \'2026-01-01 00:00:00+00\'::timestamptz'
    bind = ActiveRecord::Relation::QueryAttribute.new('t', time.getlocal, ActiveRecord::Type::DateTime.new)
    assert_equal true, connection.select_value(sql, nil, [bind])
  end

  private

  def connection; ActiveRecord::Base.connection; end

  def session_zone; connection.select_value('SHOW TIME ZONE'); end

  def set_process_zone(id)
    java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone(id))
  end
end
