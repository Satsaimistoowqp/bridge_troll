class MeetupUsersController < ApplicationController
  before_filter :authenticate_user!

  def index
    @attendances = {}
    empty_attendance_hash = Role.all.inject({}) do |hsh, role|
      hsh[role.id] = 0
      hsh
    end

    grouped_rsvps = Rsvp.where(user_type: 'MeetupUser').select('user_id, role_id, count(*) count').group('role_id, user_id')
    grouped_rsvps.all.each do |rsvp_group|
      @attendances[rsvp_group.user_id] ||= empty_attendance_hash.clone
      @attendances[rsvp_group.user_id][rsvp_group.role_id] = rsvp_group.count
    end

    attended = @attendances.keys

    @users = MeetupUser.order('lower(full_name)').select { |user| attended.include?(user.id) }
  end

  def show
    @user = MeetupUser.find(params[:id])
    @rsvps = @user.rsvps.includes(:event)
  end
end
