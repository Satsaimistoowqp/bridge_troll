require 'spec_helper'
require_relative 'meetup_request_fixtures'

describe MeetupImporter do
  let(:volunteer_event_id) { 1234 }
  let(:student_event_id) { 5678 }

  let(:sven) { {name: 'Sven Volunteeren', id: 2599323} }
  let(:sally) { {name: 'Sally Voluntally', id: 2604303} }
  let(:liz) { {name: 'Liz Organiz', id: 10603531} }
  let(:hugh) { {name: 'Hugh Studentu', id: 3232599} }
  let(:betty) { {name: 'Betty Studetty', id: 3032604} }
  let(:irma) { {name: 'Irma Orgorama', id: 35311060} }

  let(:all_fixture_users) { [sven, sally, liz, hugh, betty, irma] }

  let(:volunteer_event_response) {
    MeetupRequestFixtures.event_response(event_id: volunteer_event_id)
  }
  let(:volunteer_rsvp_response) {
    MeetupRequestFixtures.rsvp_response(
      event_id: volunteer_event_id,
      attendees: [sven, sally],
      organizer: liz
    )
  }

  let(:student_event_response) {
    MeetupRequestFixtures.event_response(event_id: student_event_id)
  }
  let(:student_rsvp_response) {
    MeetupRequestFixtures.rsvp_response(
      event_id: student_event_id,
      attendees: [hugh, betty],
      organizer: irma
    )
  }

  let(:event_params) {
    {
      name: 'Ruby on Rails Outreach Party for Pandas',
      volunteer_event_id: volunteer_event_id,
      student_event_id: student_event_id
    }
  }

  before do
    ENV['MEETUP_API_KEY'] = 'sandwich'
    stubs = [
      {event_id: volunteer_event_id, event_response: volunteer_event_response, rsvp_response: volunteer_rsvp_response},
      {event_id: student_event_id, event_response: student_event_response, rsvp_response: student_rsvp_response},
    ]
    stubs.each do |stub_data|
      stub_request(:get, "https://api.meetup.com/2/event/#{stub_data[:event_id]}?key=sandwich&sign=true").to_return({body: stub_data[:event_response].to_json})
      stub_request(:get, "https://api.meetup.com/2/rsvps?key=sandwich&sign=true&event_id=#{stub_data[:event_id]}&fields=host").to_return({body: stub_data[:rsvp_response].to_json})      
    end

    @importer = MeetupImporter.new
  end

  it "merges student and volunteer events into one mega-event" do
    expect {
      @importer.import_student_and_volunteer_event(event_params)
    }.to change(Event, :count).by(1)
    
    event = Event.last
    
    event.meetup_volunteer_event_id.should == volunteer_event_id
    event.meetup_student_event_id.should == student_event_id
  end

  it "creates Event entries for historical Railsbridge meetup events" do
    expect {
      @importer.import_student_and_volunteer_event(event_params)
    }.to change(Event, :count).by(1)

    event = Event.last

    event.title.should == 'Ruby on Rails Outreach Party for Pandas'
    event.details.should == 'my complicated details'
  end

  it "creates Location entries for each venue" do
    expect {
      @importer.import_student_and_volunteer_event(event_params)
    }.to change(Location, :count).by(1)

    location = Event.last.location
    location.name.should == 'Carbon Five'
    location.address_1.should == '585 Howard Street'
    location.address_2.should == 'Floor 2'
    location.city.should == 'San Francisco'
    location.state.should == 'CA'
    location.zip.should == '94105'
  end

  it "creates MeetupUser records for users who have RSVPed 'yes' to an event" do
    expect {
      @importer.import_student_and_volunteer_event(event_params)
    }.to change(MeetupUser, :count).by(all_fixture_users.count)

    event = Event.last

    event.student_rsvps.map { |rsvp| rsvp.user.full_name }.should =~ ["Hugh Studentu", "Betty Studetty"]
    event.volunteer_rsvps.map { |rsvp| rsvp.user.full_name }.should =~ ["Sven Volunteeren", "Sally Voluntally"]
    event.organizer_rsvps.map { |rsvp| rsvp.user.full_name }.should =~ ["Liz Organiz", "Irma Orgorama"]

    all_fixture_users.each do |fixture_user|
      MeetupUser.where(full_name: fixture_user[:name]).first.meetup_id.should == fixture_user[:id]
    end
  end

  context "when a user was assigned as volunteer to the volunteer meetup but organizer to the student meetup" do
    let(:volunteer_rsvp_response) {
      MeetupRequestFixtures.rsvp_response(
        event_id: volunteer_event_id,
        attendees: [sven, irma],
        organizer: liz
      )
    }
    let(:student_rsvp_response) {
      MeetupRequestFixtures.rsvp_response(
        event_id: student_event_id,
        attendees: [sven, hugh],
        organizer: irma
      )
    }

    it "records them as being an organizer" do
      @importer.import_student_and_volunteer_event(event_params)

      event = Event.last
      event.organizer_rsvps.map { |rsvp| rsvp.user.full_name }.should =~ ["Liz Organiz", "Irma Orgorama"]
    end
  end

  it "can sanitize invalid utf-8" do
    @importer.sanitize("Here\x92s the timeline").should == 'Heres the timeline'
  end

  describe "association to meetup users" do
    let(:volunteer_rsvp_response) {
      MeetupRequestFixtures.rsvp_response(
        event_id: volunteer_event_id,
        attendees: [sven, sally],
        organizer: liz
      )
    }
    let(:student_rsvp_response) {
      MeetupRequestFixtures.rsvp_response(
        event_id: student_event_id,
        attendees: [sven, hugh],
        organizer: liz
      )
    }
    let(:bridgetroll_user) { create(:user) }

    before do
      @importer.import_student_and_volunteer_event(event_params)
      @event = Event.where(meetup_volunteer_event_id: volunteer_event_id).first

      @sven_model = MeetupUser.where(meetup_id: sven[:id]).first
      @sally_model = MeetupUser.where(meetup_id: sally[:id]).first
    end

    it "claims existing RSVPs when associating" do
      @event.volunteers_with_legacy.should =~ [@sven_model, @sally_model]

      @importer.associate_user(bridgetroll_user, sven[:id])

      @event.reload.volunteers_with_legacy.should =~ [bridgetroll_user, @sally_model]
    end

    context "when a bridgetroll user is already associated to a meetup user" do
      before do
        @importer.associate_user(bridgetroll_user, sven[:id])
      end

      it "removes claim to RSVPs when disassociating" do
        @importer.disassociate_user(bridgetroll_user)

        @event.reload.volunteers_with_legacy.should =~ [@sven_model, @sally_model]
      end
    end
  end
end