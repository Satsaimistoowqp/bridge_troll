module EventsHelper
  def get_volunteer_skills(volunteer)
    profile = volunteer.profile
    @skills = []
    @skills << 'Teaching'     if(profile.teaching)
    @skills << 'TA-ing'       if(profile.taing)
    @skills << 'Coordinating' if(profile.coordinating)
    @skills << 'Childcare'    if(profile.childcaring)
    @skills << 'Writing'      if(profile.writing)
    @skills << 'Hacking'      if(profile.hacking)
    @skills << 'Designing'    if(profile.designing)
    @skills << 'Evangelizing' if(profile.evangelizing)
    @skills << 'Mentoring'    if(profile.mentoring)
    @skills << 'Mac OS X'     if(profile.macosx)
    @skills << 'Windows'      if(profile.windows)
    @skills << 'Linux'        if(profile.linux)
    @skills.join(', ')
  end

  def teachers_count(volunteers)
    volunteers.select(&:teaching_only?).count
  end

  def tas_count(volunteers)
    volunteers.select(&:taing_only?).count
  end

  def teach_or_ta_count(volunteers)
    volunteers.select(&:teaching_and_taing?).count
  end

  def not_teach_or_ta_count(volunteers)
    volunteers.select(&:neither_teaching_nor_taing?).count
  end

  def organizer_title
    @event.organizers.length > 1 ? "Organizers:" : "Organizer:"
  end

  def organizer_list
    @event.organizers.length == 0 ?  [] : @event.organizers
  end

  def partitioned_volunteer_list(volunteers, type)
    partition = volunteers.select(&type)   # partition = volunteers.select {|volunteer| volunteer.send(type)}

    content_tag "ol" do
      partition.map { |v| partitioned_volunteer_tag(v) }.join('').html_safe
    end
  end

  def partitioned_volunteer_tag(volunteer)
    content_tag "li","#{volunteer.full_name} - #{volunteer.email}", :class => volunteer_class(volunteer)
  end

  private

  def volunteer_class(volunteer)
    return "both"  if volunteer.teaching_and_taing?
    return "teach" if volunteer.teaching_only?
    return "ta"    if volunteer.taing_only?
    return "none"  if volunteer.neither_teaching_nor_taing?
  end
end
