require 'spec_helper'

describe "Events" do

  it "should create a new event" do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit events_path
    click_link "New Event"

    fill_in "Title", :with=>"February Event"
    select "February",:from =>"event[date(2i)]"
    click_button "Create Event"

    page.should have_content("February Event")
    page.should have_content("This event currently has no location!")

    visit events_path

    page.should have_content("February Event")

  end
  
  it "should allow user to volunteer for event" do
    @user = Factory(:user)
    @user.confirm!
    visit new_user_session_path

    fill_in "Email", :with => @user.email
    fill_in "Password", :with => @user.password
    click_button "Sign in"
    visit events_path
    click_link "New Event"
    fill_in "Title", :with => "March Event"
    select "February",:from =>"event[date(2i)]"
    click_button "Create Event"
    visit events_path

    page.should have_content("March Event")
    page.should have_content("Volunteer")
    @event = Event.where(:title=> 'March Event').first
    visit volunteer_path(@event)
    page.should have_content("Thanks for volunteering")
    @rsvp = VolunteerRsvp.where(:event_id=> @event_id, :user_id => @user.id).first
#    @rsvp.should_not equal(nil)
    
  end

end
