Bridgetroll.Views.SectionOrganizer = (function () {
  function addSectionView(section) {
    var sectionView = new Bridgetroll.Views.Section({
      section: section,
      attendees: this.attendees
    });

    this.addSubview(sectionView);
    this.listenTo(sectionView, 'section:changed', this.render);
    this.listenTo(sectionView, 'attendee_drag:start', function () {
      this.poller.suspendPolling();
    });
    this.listenTo(sectionView, 'attendee_drag:stop', function () {
      this.poller.resumePolling();
    });

    if (section.get('id')) {
      this.sections.add(section);
    }
  }

  return Bridgetroll.Views.Base.extend({
    template: 'section_organizer/section_organizer',

    events: {
      'click .add-section': 'onAddSectionClick',
      'click .show-os': 'onShowOSClick',
      'click .show-unassigned': 'onShowUnassignedClick',
      'click .poll-for-changes': 'onPollForChangesClick'
    },

    initialize: function (options) {
      this._super('initialize', arguments);
      this.event_id = options.event_id;
      this.attendees = options.attendees;
      this.sections = options.sections;

      this.showOS = false;
      this.showUnassigned = true;

      this.unsortedSection = new Bridgetroll.Models.Section({
        id: null,
        name: 'Unsorted Attendees'
      });

      this.listenTo(this.attendees, 'add remove change', this.render);
      this.listenTo(this.sections, 'add remove', this.updateSectionViewsAndRender);
      this.listenTo(this.sections, 'change', this.render);

      this.listenTo(this.attendees, 'add remove change', function () {
        this.poller.resetPollingInterval();
      });
      this.listenTo(this.sections, 'add remove change', function () {
        this.poller.resetPollingInterval();
      });

      this.poller = new Bridgetroll.Services.Poller({
        pollUrl: 'organize_sections.json',
        afterPoll: _.bind(function (json) {
          this.sections.set(json['sections']);
          this.attendees.set(json['attendees']);
          this.render();
        }, this)
      });

      this.updateSectionViewsAndRender();
    },

    updateSectionViewsAndRender: function () {
      this.updateSectionViews();
      this.render();
    },

    updateSectionViews: function () {
      _.invoke(this.subViews, 'destroy');

      addSectionView.call(this, this.unsortedSection);

      this.sections.each(_.bind(function (section) {
        addSectionView.call(this, section);
      }, this));
      this.render();
    },

    context: function () {
      return {
        showUnassigned: this.showUnassigned,
        showOS: this.showOS,
        polling: this.poller.polling()
      };
    },

    postRender: function () {
      this.$el.off();
      this.$el.on('mousemove', _.throttle(_.bind(function () {
        this.poller.stallPolling();
      }, this), 100));
    },

    onAddSectionClick: function () {
      var section = new Bridgetroll.Models.Section({event_id: this.event_id});
      section
        .save()
        .success(_.bind(function (sectionJson) {
          var section = new Bridgetroll.Models.Section(sectionJson);
          addSectionView.call(this, section);
        }, this))
        .error(function () {
          alert('Error creating section.')
        });
    },

    onShowOSClick: function () {
      this.showOS = !this.showOS;
      this.render();
      this.$el.toggleClass('showing-os', this.showOS);
    },

    onShowUnassignedClick: function () {
      this.showUnassigned = !this.showUnassigned;
      this.render();
      this.$el.toggleClass('showing-unassigned', this.showUnassigned);
    },

    onPollForChangesClick: function () {
      this.poller.togglePolling();
      this.render();
    }
  });
})();
