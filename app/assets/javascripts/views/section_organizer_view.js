Bridgetroll.Views.SectionOrganizer = Bridgetroll.Views.Base.extend({
  template: 'section_organizer/section_organizer',

  events: {
    'click .add-section': 'addSection'
  },

  initialize: function (options) {
    this._super('initialize', arguments);
    this.students = options.students;
    this.listenTo(this.students, 'change', this.render);

    var section = new Bridgetroll.Views.Section({
      title: 'Unsorted Students',
      students: options.students,
      volunteers: options.volunteers
    });
    this.subViews.push(section);
    this.render();
  },

  addSection: function () {
    var sectionStudents = new Bridgetroll.Collections.Student();
    var sectionVolunteers = new Bridgetroll.Collections.Volunteer();
    var section = new Bridgetroll.Views.Section({
      title: 'New Section',
      students: sectionStudents,
      volunteers: sectionVolunteers
    });
    this.subViews.push(section);
    this.render();
  }
});
