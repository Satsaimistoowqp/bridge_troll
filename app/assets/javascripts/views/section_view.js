Bridgetroll.Views.Section = Bridgetroll.Views.Base.extend({
  className: 'bridgetroll-section',
  template: 'section_organizer/section',

  events: {
    'dblclick .title': 'onTitleDoubleClick',
    'click .destroy': 'onDestroyClick'
  },

  initialize: function (options) {
    this._super('initialize', arguments);

    this.section = options.section;

    this.attendees = options.attendees;
  },

  context: function () {
    return {
      title: this.section.get('name'),
      students: _.pluck(this.students(), 'attributes'),
      volunteers: _.pluck(this.volunteers(), 'attributes'),
      destructable: !this.section.isUnassigned()
    }
  },

  students: function () {
    var students = this.attendees.where({
      role_id: Bridgetroll.Enums.Role.STUDENT,
      section_id: this.section.get('id')
    });
    return _.sortBy(students, function (student) {
      return student.get('class_level');
    });
  },

  volunteers: function () {
    return this.attendees.where({
      role_id: Bridgetroll.Enums.Role.VOLUNTEER,
      section_id: this.section.get('id')
    });
  },

  attendeeDragging: function (el, dd) {
    var $attendee = $(dd.drag);
    $attendee.addClass('dragging');
    $attendee.css({
      top: dd.offsetY,
      left: dd.offsetX
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
    this.$('.attendee').on('drag', this.attendeeDragging);
    this.$('.attendee').on('dragend', this.attendeeDropped);

    this.$el.drop(_.bind(function (el, dd) {
      var $attendee = $(dd.drag);
      this.moveAttendeeToSection($attendee.data('id'));
    }, this));
  },

  onTitleDoubleClick: function () {
    if (this.section.isUnassigned()) {
      return;
    }

    var newName = window.prompt('Enter the new name for ' + this.section.get('name'));
    if (newName) {
      this.section
        .save({name: newName})
        .success(_.bind(function () {
          this.render();
        }, this))
        .error(function () {
          alert("Error updating section.");
        });
    }
  },

  onDestroyClick: function () {
    var confirmed = window.confirm('Are you sure you want to destroy ' + this.section.get('name') + '?\n\nAll Students and Volunteers will return to being Unassigned.');
    if (confirmed) {
      _.invoke(this.students(), 'unassign');
      _.invoke(this.volunteers(), 'unassign');
      this.destroy();
      this.section.destroy();
    }
  }
});