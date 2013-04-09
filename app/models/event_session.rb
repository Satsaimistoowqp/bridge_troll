class EventSession < ActiveRecord::Base
  attr_accessible :starts_at, :ends_at, :name
  validates_presence_of :starts_at, :ends_at, :name
  validates_uniqueness_of :name, scope: [:event_id]

  belongs_to :event
  has_many :rsvp_sessions, dependent: :destroy
  has_many :rsvps, :through => :rsvp_sessions

  def starts_at
    event ? date_in_time_zone(:starts_at) : read_attribute(:starts_at)
  end

  def ends_at
    event ? date_in_time_zone(:ends_at) : read_attribute(:ends_at)
  end

  def session_date
    (starts_at ? starts_at : Date.current).strftime('%Y-%m-%d')
  end

  def date_in_time_zone start_or_end
    read_attribute(start_or_end).in_time_zone(ActiveSupport::TimeZone.new(event.time_zone))
  end
end
