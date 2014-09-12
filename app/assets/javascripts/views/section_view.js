Bridgetroll.Views.Section = Bridgetroll.Views.Base.extend({
  className: 'bridgetroll-section',
  template: 'section_organizer/section',
  attachPoint: function () {
    if (this.displayProperties.get('masonry')) {
      return '.masonry-container';
    }

    var sectionClassPrefix = '.bridgetroll-section-level.level';
    return sectionClassPrefix + (this.section.get("class_level") || 0);
  },

  events: {
    'click .info': 'onInfoClick',
    'click .edit': 'onEditClick',
    'click .destroy': 'onDestroyClick'
  },

  initialize: function (options) {
    this._super('initialize', arguments);

    this.levels = options.levels;
    this.section = options.section;
    this.attendees = options.attendees;
    this.selectedSession = options.selectedSession;
    this.displayProperties = options.displayProperties;
  },

  context: function () {
    return {
      title: this.section.get('name'),
      students: this.presentedStudents(),
      volunteers: this.presentedVolunteers(),
      destructable: !this.section.isUnassigned(),
      level: this.section.get('class_level')
    }
  },

  skipRendering: function () {
    return this.displayProperties.get('masonry') && this.section.isUnassigned();
  },

  render: function () {
    // Restore inline style and className that may have been set by Masonry
    this.$el.attr('style', '');
    this.$el.removeClass().addClass(_.result(this, 'className'));
    this._super('render', arguments);
  },

  presentedStudents: function () {
    return _.map(this.students(), _.bind(function (student) {
      return _.extend({}, student.attributes, {
        selected_session_checkins_count: student.checkedInTo(this.selectedSession.get('id'))
      });
    }, this));
  },

  presentedVolunteers: function () {
    return _.map(this.volunteers(), _.bind(function (volunteer) {
      return _.extend({}, volunteer.attributes, {
        volunteer_letter: volunteer.volunteerLetter(),
        selected_session_checkins_count: volunteer.checkedInTo(this.selectedSession.get('id'))
      });
    }, this));
  },

  students: function () {
    var students = this.attendees.where({
      role_id: Bridgetroll.Enums.Role.STUDENT,
      section_id: this.section.get('id')
    });
    return students.sort(function (a, b) {
      var left_class_level = a.get('class_level');
      var right_class_level = b.get('class_level');

      if (left_class_level !== right_class_level) {
        return (left_class_level > right_class_level) ? 1 : -1;
      }

      var left_full_name = a.get('full_name');
      var right_full_name = b.get('full_name');
      if (left_full_name === right_full_name) {
        return 0;
      }
      return (left_full_name > right_full_name) ? 1 : -1;
    });
  },

  volunteers: function () {
    var volunteers = this.attendees.where({
      role_id: Bridgetroll.Enums.Role.VOLUNTEER,
      section_id: this.section.get('id')
    });
    var organizers = this.attendees.where({
      role_id: Bridgetroll.Enums.Role.ORGANIZER,
      section_id: this.section.get('id')
    });
    return _.sortBy(_.union(volunteers, organizers), function (volunteer) {
      return volunteer.get('full_name');
    });
  },

  attendeeDragging: function (el, dd) {
    this.trigger('attendee_drag:start');
    var $attendee = $(dd.drag);
    $attendee.addClass('dragging');
    var parentOffset = $attendee.offsetParent().offset();
    $attendee.css({
      top: dd.offsetY - parentOffset.top,
      left: dd.offsetX - parentOffset.left
    });
  },

  attendeeDropped: function (el, dd) {
    $(dd.drag).removeClass('dragging');
    $(dd.drag).css({
      top: '',
      left: ''
    });
  },

  moveAttendeeToSection: function (attendee_id) {
    this.trigger('attendee_drag:stop');
    var attendee = this.attendees.where({id: attendee_id})[0];
    attendee
      .save({section_id: this.section.get('id')})
      .success(_.bind(function () {
        this.trigger('section:changed');
      }, this))
      .error(function () {
        alert("Error reassigning attendee.");
      });
  },

  postRender: function () {
    this.$('.attendee').on('drag', _.bind(this.attendeeDragging, this));
    this.$('.attendee').on('dragend', _.bind(this.attendeeDropped, this));

    this.$el.drop(_.bind(function (el, dd) {
      var $attendee = $(dd.drag);
      this.moveAttendeeToSection($attendee.data('id'));
    }, this));
  },

  onInfoClick: function (e) {
    var id = $(e.target).closest('.attendee').data('id');
    var attendee = this.attendees.findWhere({id: id});
    var detailView = new Bridgetroll.Views.AttendeeDetail({model: attendee});
    detailView.showModally();
  },

  onEditClick: function (e) {
    if (this.section.isUnassigned()) {
      return;
    }

    var sectionView = new Bridgetroll.Views.EditSection({
      model: this.section,
      levels: this.levels
    });
    sectionView.showModally();
  },

  onDestroyClick: function () {
    var confirmed = window.confirm('Are you sure you want to destroy ' + this.section.get('name') + '?\n\nAll Students and Volunteers in this section will return to being Unassigned.');
    if (confirmed) {
      _.invoke(this.students(), 'unassign');
      _.invoke(this.volunteers(), 'unassign');
      this.destroy();
      this.section.destroy();
    }
  }
});